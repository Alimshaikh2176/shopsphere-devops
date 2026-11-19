#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$HOME/shopsphere"
BACKEND_DIR="$PROJECT_DIR/application/backend"

echo "=========================================="
echo "       ShopSphere Backend Setup"
echo "=========================================="

if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo is required."
    exit 1
fi

echo "[1/7] Installing system packages..."
sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip \
    postgresql postgresql-contrib openssl

echo "[2/7] Starting PostgreSQL..."
sudo systemctl enable --now postgresql

mkdir -p "$BACKEND_DIR/app"
cd "$BACKEND_DIR"

echo "[3/7] Creating database credentials..."

if [[ ! -f .env ]]; then
    DB_PASSWORD="$(openssl rand -hex 24)"
    JWT_SECRET="$(openssl rand -hex 32)"
    ADMIN_PASSWORD="$(openssl rand -hex 16)"

    cat > .env <<EOF
DATABASE_URL=postgresql+psycopg://shopsphere_user:${DB_PASSWORD}@127.0.0.1:5432/shopsphere
JWT_SECRET=${JWT_SECRET}
JWT_ALGORITHM=HS256
ACCESS_TOKEN_MINUTES=60
ADMIN_EMAIL=admin@shopsphere.local
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF
    chmod 600 .env
else
    echo "Existing .env found. Keeping existing credentials."
fi

# Read the generated database password.
DB_PASSWORD="$(sed -n 's/^DATABASE_URL=postgresql+psycopg:\/\/shopsphere_user:\([^@]*\)@.*/\1/p' .env)"

if [[ -z "$DB_PASSWORD" ]]; then
    echo "ERROR: Could not read database password from .env"
    exit 1
fi

echo "[4/7] Creating PostgreSQL role and database..."

ROLE_EXISTS="$(sudo -u postgres psql -tAc \
    "SELECT 1 FROM pg_roles WHERE rolname='shopsphere_user'")"

if [[ "$ROLE_EXISTS" != "1" ]]; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 \
        -c "CREATE ROLE shopsphere_user LOGIN PASSWORD '${DB_PASSWORD}';"
else
    sudo -u postgres psql -v ON_ERROR_STOP=1 \
        -c "ALTER ROLE shopsphere_user WITH LOGIN PASSWORD '${DB_PASSWORD}';"
fi

DB_EXISTS="$(sudo -u postgres psql -tAc \
    "SELECT 1 FROM pg_database WHERE datname='shopsphere'")"

if [[ "$DB_EXISTS" != "1" ]]; then
    sudo -u postgres createdb -O shopsphere_user shopsphere
fi

sudo -u postgres psql -v ON_ERROR_STOP=1 \
    -c "GRANT ALL PRIVILEGES ON DATABASE shopsphere TO shopsphere_user;"

sudo -u postgres psql -d shopsphere -v ON_ERROR_STOP=1 \
    -c "GRANT ALL ON SCHEMA public TO shopsphere_user;"

echo "[5/7] Creating Python environment and installing dependencies..."

python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip

cat > requirements.txt <<'EOF'
fastapi
uvicorn[standard]
sqlalchemy
psycopg[binary]
pydantic
python-dotenv
pwdlib[argon2]
PyJWT
email-validator
EOF

.venv/bin/pip install -r requirements.txt

echo "[6/7] Creating ShopSphere FastAPI application..."

mkdir -p app

cat > app/__init__.py <<'EOF'
EOF

cat > app/main.py <<'PYTHON'
import os
from datetime import datetime, timedelta, timezone

import jwt
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, EmailStr, Field
from pwdlib import PasswordHash
from sqlalchemy import (
    Boolean, DateTime, ForeignKey, Integer, Numeric, String,
    create_engine, select
)
from sqlalchemy.orm import (
    DeclarativeBase, Mapped, Session, mapped_column,
    relationship, sessionmaker
)

load_dotenv()

DATABASE_URL = os.environ["DATABASE_URL"]
JWT_SECRET = os.environ["JWT_SECRET"]
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
TOKEN_MINUTES = int(os.getenv("ACCESS_TOKEN_MINUTES", "60"))

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)

class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(20), default="customer")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class Product(Base):
    __tablename__ = "products"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(180), index=True)
    description: Mapped[str] = mapped_column(String(1000), default="")
    price: Mapped[float] = mapped_column(Numeric(10, 2))
    stock: Mapped[int] = mapped_column(Integer, default=0)
    active: Mapped[bool] = mapped_column(Boolean, default=True)

class CartItem(Base):
    __tablename__ = "cart_items"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    product: Mapped[Product] = relationship()

class Order(Base):
    __tablename__ = "orders"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    total: Mapped[float] = mapped_column(Numeric(10, 2))
    status: Mapped[str] = mapped_column(String(30), default="placed")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    items: Mapped[list["OrderItem"]] = relationship(
        back_populates="order", cascade="all, delete-orphan"
    )

class OrderItem(Base):
    __tablename__ = "order_items"
    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"))
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    product_name: Mapped[str] = mapped_column(String(180))
    unit_price: Mapped[float] = mapped_column(Numeric(10, 2))
    quantity: Mapped[int] = mapped_column(Integer)
    order: Mapped[Order] = relationship(back_populates="items")

Base.metadata.create_all(bind=engine)

password_hash = PasswordHash.recommended()
security = HTTPBearer()

app = FastAPI(
    title="ShopSphere API",
    description="E-commerce backend for the ShopSphere DevOps project",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_token(user: User) -> str:
    expires = datetime.now(timezone.utc) + timedelta(minutes=TOKEN_MINUTES)
    return jwt.encode(
        {"sub": str(user.id), "role": user.role, "exp": expires},
        JWT_SECRET,
        algorithm=JWT_ALGORITHM
    )

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    try:
        payload = jwt.decode(
            credentials.credentials, JWT_SECRET,
            algorithms=[JWT_ALGORITHM]
        )
        user_id = int(payload["sub"])
    except (jwt.InvalidTokenError, KeyError, TypeError, ValueError):
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user

def admin_only(user: User = Depends(get_current_user)):
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return user

class RegisterInput(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)

class LoginInput(BaseModel):
    email: EmailStr
    password: str

class ProductInput(BaseModel):
    name: str = Field(min_length=2, max_length=180)
    description: str = Field(default="", max_length=1000)
    price: float = Field(gt=0)
    stock: int = Field(ge=0)

class CartInput(BaseModel):
    product_id: int
    quantity: int = Field(gt=0, le=100)

@app.get("/")
def root():
    return {"message": "Welcome to ShopSphere API", "docs": "/docs"}

@app.get("/health")
def health():
    try:
        with engine.connect() as connection:
            connection.exec_driver_sql("SELECT 1")
        return {"status": "healthy", "database": "connected"}
    except Exception:
        raise HTTPException(status_code=503, detail="Database unavailable")

@app.post("/api/auth/register", status_code=201)
def register(data: RegisterInput, db: Session = Depends(get_db)):
    email = data.email.lower()
    if db.scalar(select(User).where(User.email == email)):
        raise HTTPException(status_code=409, detail="Email already registered")

    user = User(
        name=data.name,
        email=email,
        password_hash=password_hash.hash(data.password),
        role="customer"
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"id": user.id, "name": user.name, "email": user.email}

@app.post("/api/auth/login")
def login(data: LoginInput, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == data.email.lower()))
    if not user or not password_hash.verify(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect email or password")
    return {
        "access_token": create_token(user),
        "token_type": "bearer",
        "user": {"id": user.id, "name": user.name, "email": user.email, "role": user.role}
    }

@app.get("/api/auth/me")
def me(user: User = Depends(get_current_user)):
    return {"id": user.id, "name": user.name, "email": user.email, "role": user.role}

@app.get("/api/products")
def list_products(db: Session = Depends(get_db)):
    products = db.scalars(
        select(Product).where(Product.active.is_(True)).order_by(Product.id)
    ).all()
    return products

@app.get("/api/products/{product_id}")
def get_product(product_id: int, db: Session = Depends(get_db)):
    product = db.get(Product, product_id)
    if not product or not product.active:
        raise HTTPException(status_code=404, detail="Product not found")
    return product

@app.post("/api/admin/products", status_code=201)
def add_product(
    data: ProductInput,
    db: Session = Depends(get_db),
    admin: User = Depends(admin_only)
):
    product = Product(**data.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product

@app.put("/api/admin/products/{product_id}")
def update_product(
    product_id: int,
    data: ProductInput,
    db: Session = Depends(get_db),
    admin: User = Depends(admin_only)
):
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    for key, value in data.model_dump().items():
        setattr(product, key, value)
    db.commit()
    db.refresh(product)
    return product

@app.delete("/api/admin/products/{product_id}")
def deactivate_product(
    product_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(admin_only)
):
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    product.active = False
    db.commit()
    return {"message": "Product deactivated"}

@app.get("/api/cart")
def view_cart(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    items = db.scalars(
        select(CartItem).where(CartItem.user_id == user.id)
    ).all()
    result = []
    total = 0
    for item in items:
        if item.product and item.product.active:
            subtotal = float(item.product.price) * item.quantity
            total += subtotal
            result.append({
                "id": item.id,
                "product_id": item.product_id,
                "product_name": item.product.name,
                "unit_price": float(item.product.price),
                "quantity": item.quantity,
                "subtotal": round(subtotal, 2)
            })
    return {"items": result, "total": round(total, 2)}

@app.post("/api/cart/items", status_code=201)
def add_cart_item(
    data: CartInput,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    product = db.get(Product, data.product_id)
    if not product or not product.active:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.stock < data.quantity:
        raise HTTPException(status_code=400, detail="Insufficient stock")

    item = db.scalar(select(CartItem).where(
        CartItem.user_id == user.id,
        CartItem.product_id == product.id
    ))
    if item:
        item.quantity += data.quantity
    else:
        item = CartItem(user_id=user.id, product_id=product.id, quantity=data.quantity)
        db.add(item)

    db.commit()
    return {"message": "Cart updated"}

@app.delete("/api/cart/items/{item_id}")
def remove_cart_item(
    item_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    item = db.get(CartItem, item_id)
    if not item or item.user_id != user.id:
        raise HTTPException(status_code=404, detail="Cart item not found")
    db.delete(item)
    db.commit()
    return {"message": "Item removed"}

@app.post("/api/orders", status_code=201)
def place_order(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        items = db.scalars(
            select(CartItem).where(CartItem.user_id == user.id)
        ).all()
        if not items:
            raise HTTPException(status_code=400, detail="Cart is empty")

        total = 0
        order = Order(user_id=user.id, total=0, status="placed")
        db.add(order)
        db.flush()

        for item in items:
            product = db.get(Product, item.product_id)
            if not product or not product.active or product.stock < item.quantity:
                raise HTTPException(
                    status_code=400,
                    detail=f"Product unavailable or insufficient stock: {item.product_id}"
                )
            price = float(product.price)
            total += price * item.quantity
            product.stock -= item.quantity
            order.items.append(OrderItem(
                product_id=product.id,
                product_name=product.name,
                unit_price=price,
                quantity=item.quantity
            ))
            db.delete(item)

        order.total = round(total, 2)
        db.commit()
        db.refresh(order)
        return {
            "order_id": order.id,
            "total": float(order.total),
            "status": order.status
        }
    except Exception:
        db.rollback()
        raise

@app.get("/api/orders")
def order_history(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    orders = db.scalars(
        select(Order).where(Order.user_id == user.id).order_by(Order.id.desc())
    ).all()
    return [
        {
            "id": order.id,
            "total": float(order.total),
            "status": order.status,
            "created_at": order.created_at,
            "items": [
                {
                    "product_id": item.product_id,
                    "product_name": item.product_name,
                    "unit_price": float(item.unit_price),
                    "quantity": item.quantity
                }
                for item in order.items
            ]
        }
        for order in orders
    ]

def initialize_data():
    with SessionLocal() as db:
        admin_email = os.environ["ADMIN_EMAIL"].lower()
        admin = db.scalar(select(User).where(User.email == admin_email))
        if not admin:
            db.add(User(
                name="ShopSphere Admin",
                email=admin_email,
                password_hash=password_hash.hash(os.environ["ADMIN_PASSWORD"]),
                role="admin"
            ))

        if not db.scalar(select(Product.id).limit(1)):
            db.add_all([
                Product(name="Wireless Headphones", description="Bluetooth over-ear headphones", price=2499, stock=25),
                Product(name="Smart Watch", description="Fitness and notification smartwatch", price=3999, stock=15),
                Product(name="Running Shoes", description="Lightweight everyday running shoes", price=1999, stock=30),
                Product(name="Laptop Backpack", description="Water-resistant laptop backpack", price=1299, stock=20),
                Product(name="USB-C Charger", description="Fast charging USB-C adapter", price=899, stock=40)
            ])
        db.commit()

initialize_data()
PYTHON

echo "[7/7] Protecting secrets and starting ShopSphere API..."

touch "$PROJECT_DIR/.gitignore"
for entry in ".env" ".venv/" "__pycache__/" "*.pyc"; do
    grep -qxF "$entry" "$PROJECT_DIR/.gitignore" || echo "$entry" >> "$PROJECT_DIR/.gitignore"
done

echo
echo "=========================================="
echo "ShopSphere backend setup completed."
echo "=========================================="
echo "API documentation: http://YOUR_EC2_PUBLIC_IP:8000/docs"
echo "Health endpoint:   http://YOUR_EC2_PUBLIC_IP:8000/health"
echo
echo "Admin email: $(grep '^ADMIN_EMAIL=' .env | cut -d= -f2)"
echo "Admin password: $(grep '^ADMIN_PASSWORD=' .env | cut -d= -f2)"
echo "Credentials are stored in: $BACKEND_DIR/.env"
echo
echo "Starting API. Press CTRL+C to stop."
echo "=========================================="

exec .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
