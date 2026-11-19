#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT="$HOME/shopsphere"
FRONTEND="$PROJECT/application/frontend"

echo "======================================"
echo "     ShopSphere Frontend Setup"
echo "======================================"

# Install Node.js 22 if it is not already installed.
if ! command -v node >/dev/null 2>&1 || \
   ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 20)' 2>/dev/null; then
    echo "[1/6] Installing Node.js 22..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "[1/6] Existing Node.js installation found."
fi

echo "Node: $(node --version)"
echo "NPM:  $(npm --version)"

echo "[2/6] Creating frontend structure..."
mkdir -p "$FRONTEND/src"
cd "$FRONTEND"

cat > package.json <<'EOF'
{
  "name": "shopsphere-frontend",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0",
    "build": "vite build",
    "preview": "vite preview --host 0.0.0.0"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "lucide-react": "^0.468.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.4",
    "vite": "^5.4.14"
  }
}
EOF

cat > index.html <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="theme-color" content="#111827" />
    <meta name="description" content="ShopSphere online shopping" />
    <title>ShopSphere | Online Shopping</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

cat > vite.config.js <<'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true
      },
      '/health': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true
      }
    }
  }
})
EOF

echo "[3/6] Creating React application..."

cat > src/main.jsx <<'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './style.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
EOF

cat > src/App.jsx <<'EOF'
import { useEffect, useState } from 'react'
import {
  ShoppingBag, ShoppingCart, Search, User, LogOut,
  Package, Menu, X, Plus, Minus, Trash2, History,
  ArrowRight, ShieldCheck
} from 'lucide-react'

const money = value => `₹${Number(value).toLocaleString('en-IN', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2
})}`

async function api(path, options = {}, token = '') {
  const headers = { 'Content-Type': 'application/json', ...options.headers }
  if (token) headers.Authorization = `Bearer ${token}`

  const response = await fetch(path, { ...options, headers })
  const data = await response.json().catch(() => ({}))

  if (!response.ok) {
    throw new Error(data.detail || `Request failed (${response.status})`)
  }
  return data
}

export default function App() {
  const [products, setProducts] = useState([])
  const [cart, setCart] = useState({ items: [], total: 0 })
  const [orders, setOrders] = useState([])
  const [token, setToken] = useState(() => localStorage.getItem('shopsphere_token') || '')
  const [user, setUser] = useState(null)
  const [search, setSearch] = useState('')
  const [view, setView] = useState('shop')
  const [authMode, setAuthMode] = useState('login')
  const [authOpen, setAuthOpen] = useState(false)
  const [mobileMenu, setMobileMenu] = useState(false)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  const [authForm, setAuthForm] = useState({
    name: '', email: '', password: ''
  })

  const [cartBusy, setCartBusy] = useState(false)

  function notify(text, isError = false) {
    setMessage(isError ? '' : text)
    setError(isError ? text : '')
    window.setTimeout(() => {
      setMessage('')
      setError('')
    }, 4000)
  }

  async function loadProducts() {
    const data = await api('/api/products')
    setProducts(data)
  }

  async function loadCart(activeToken = token) {
    if (!activeToken) return
    const data = await api('/api/cart', {}, activeToken)
    setCart(data)
  }

  async function loadOrders(activeToken = token) {
    if (!activeToken) return
    const data = await api('/api/orders', {}, activeToken)
    setOrders(data)
  }

  async function loadUser(activeToken) {
    const data = await api('/api/auth/me', {}, activeToken)
    setUser(data)
  }

  useEffect(() => {
    async function initialize() {
      try {
        await loadProducts()
        if (token) {
          try {
            await loadUser(token)
            await loadCart(token)
          } catch {
            logout(false)
          }
        }
      } catch (err) {
        notify(err.message, true)
      } finally {
        setLoading(false)
      }
    }
    initialize()
  }, [])

  function logout(showMessage = true) {
    localStorage.removeItem('shopsphere_token')
    setToken('')
    setUser(null)
    setCart({ items: [], total: 0 })
    setOrders([])
    setView('shop')
    if (showMessage) notify('You have been logged out.')
  }

  async function submitAuth(event) {
    event.preventDefault()
    setBusy(true)
    try {
      if (authMode === 'register') {
        await api('/api/auth/register', {
          method: 'POST',
          body: JSON.stringify(authForm)
        })
      }

      const result = await api('/api/auth/login', {
        method: 'POST',
        body: JSON.stringify({
          email: authForm.email,
          password: authForm.password
        })
      })

      localStorage.setItem('shopsphere_token', result.access_token)
      setToken(result.access_token)
      setUser(result.user)
      await loadCart(result.access_token)
      setAuthOpen(false)
      setAuthForm({ name: '', email: '', password: '' })
      notify(`Welcome, ${result.user.name}!`)
    } catch (err) {
      notify(err.message, true)
    } finally {
      setBusy(false)
    }
  }

  async function addToCart(productId) {
    if (!token) {
      setAuthOpen(true)
      setAuthMode('login')
      notify('Please log in before adding items.')
      return
    }
    try {
      await api('/api/cart/items', {
        method: 'POST',
        body: JSON.stringify({ product_id: productId, quantity: 1 })
      }, token)
      await loadCart()
      notify('Product added to cart.')
    } catch (err) {
      notify(err.message, true)
    }
  }

  async function removeItem(itemId) {
    try {
      await api(`/api/cart/items/${itemId}`, { method: 'DELETE' }, token)
      await loadCart()
      notify('Item removed.')
    } catch (err) {
      notify(err.message, true)
    }
  }

  async function checkout() {
    if (!token) return setAuthOpen(true)
    setCartBusy(true)
    try {
      const result = await api('/api/orders', { method: 'POST' }, token)
      await Promise.all([loadCart(), loadProducts(), loadOrders()])
      notify(`Order #${result.order_id} placed successfully!`)
      setView('orders')
    } catch (err) {
      notify(err.message, true)
    } finally {
      setCartBusy(false)
    }
  }

  async function showOrders() {
    try {
      await loadOrders()
      setView('orders')
    } catch (err) {
      notify(err.message, true)
    }
  }

  const filteredProducts = products.filter(product =>
    product.name.toLowerCase().includes(search.toLowerCase()) ||
    product.description.toLowerCase().includes(search.toLowerCase())
  )

  const icons = ['🎧', '⌚', '👟', '🎒', '🔌', '📱', '💻']

  return (
    <div className="app">
      <header className="navbar">
        <div className="nav-inner">
          <button className="brand" onClick={() => setView('shop')}>
            <span className="brand-icon"><ShoppingBag size={22} /></span>
            <span>Shop<span className="brand-accent">Sphere</span></span>
          </button>

          <nav className={mobileMenu ? 'nav-links open' : 'nav-links'}>
            <button className={view === 'shop' ? 'nav-link active' : 'nav-link'}
              onClick={() => { setView('shop'); setMobileMenu(false) }}>
              Shop
            </button>
            {user && (
              <button className={view === 'orders' ? 'nav-link active' : 'nav-link'}
                onClick={() => { showOrders(); setMobileMenu(false) }}>
                My Orders
              </button>
            )}
          </nav>

          <div className="nav-actions">
            <button className="cart-button" onClick={() => setView('cart')}>
              <ShoppingCart size={20} />
              <span>Cart</span>
              <b>{cart.items.reduce((sum, item) => sum + item.quantity, 0)}</b>
            </button>

            {user ? (
              <div className="user-menu">
                <span className="user-name"><User size={17} /> {user.name}</span>
                <button className="icon-button" title="Logout" onClick={() => logout()}>
                  <LogOut size={18} />
                </button>
              </div>
            ) : (
              <button className="login-button" onClick={() => setAuthOpen(true)}>
                <User size={17} /> Sign in
              </button>
            )}
            <button className="mobile-toggle" onClick={() => setMobileMenu(!mobileMenu)}>
              {mobileMenu ? <X /> : <Menu />}
            </button>
          </div>
        </div>
      </header>

      {(message || error) && (
        <div className={error ? 'toast error' : 'toast'}>{error || message}</div>
      )}

      <main>
        {view === 'shop' && (
          <>
            <section className="hero">
              <div className="hero-content">
                <span className="eyebrow">YOUR EVERYDAY MARKETPLACE</span>
                <h1>Find what you love.<br /><span>Shop with confidence.</span></h1>
                <p>Discover useful products at great prices, all in one place.</p>
                <button className="primary-button" onClick={() =>
                  document.getElementById('catalogue')?.scrollIntoView({ behavior: 'smooth' })
                }>
                  Explore products <ArrowRight size={18} />
                </button>
              </div>
              <div className="hero-art">
                <div className="hero-circle">🛍️</div>
                <span className="floating-card card-one">✨ Great finds</span>
                <span className="floating-card card-two">📦 Easy ordering</span>
              </div>
            </section>

            <section className="features">
              <div><Package /><span><b>Quality products</b><small>Curated essentials</small></span></div>
              <div><ShieldCheck /><span><b>Simple shopping</b><small>Easy checkout</small></span></div>
              <div><ShoppingBag /><span><b>Order tracking</b><small>View order history</small></span></div>
            </section>

            <section className="catalogue section" id="catalogue">
              <div className="section-heading">
                <div>
                  <span className="eyebrow">OUR COLLECTION</span>
                  <h2>Explore products</h2>
                  <p>Find the right products for your everyday needs.</p>
                </div>
                <div className="search-box">
                  <Search size={18} />
                  <input value={search} onChange={e => setSearch(e.target.value)}
                    placeholder="Search products..." />
                </div>
              </div>

              {loading ? <div className="empty">Loading products...</div> :
                filteredProducts.length === 0 ? <div className="empty">No products found.</div> :
                <div className="product-grid">
                  {filteredProducts.map((product, index) => (
                    <article className="product-card" key={product.id}>
                      <div className="product-art">
                        <span>{icons[index % icons.length]}</span>
                        <small>SHOPSPHERE PICK</small>
                      </div>
                      <div className="product-info">
                        <h3>{product.name}</h3>
                        <p>{product.description}</p>
                        <div className="product-bottom">
                          <strong>{money(product.price)}</strong>
                          <button onClick={() => addToCart(product.id)}
                            disabled={product.stock < 1} className="add-button">
                            <Plus size={17} /> Add
                          </button>
                        </div>
                        <small className="stock">{product.stock > 0
                          ? `${product.stock} in stock` : 'Out of stock'}</small>
                      </div>
                    </article>
                  ))}
                </div>
              }
            </section>
          </>
        )}

        {view === 'cart' && (
          <section className="section page-section">
            <span className="eyebrow">YOUR SELECTION</span>
            <h2>Shopping cart</h2>
            {!token ? (
              <div className="empty">
                Please sign in to view your cart.
                <button className="primary-button" onClick={() => setAuthOpen(true)}>Sign in</button>
              </div>
            ) : cart.items.length === 0 ? (
              <div className="empty">
                <ShoppingCart size={42} />
                <h3>Your cart is empty</h3>
                <p>Explore our catalogue and add something you love.</p>
                <button className="primary-button" onClick={() => setView('shop')}>Continue shopping</button>
              </div>
            ) : (
              <div className="cart-layout">
                <div className="cart-items">
                  {cart.items.map(item => (
                    <div className="cart-item" key={item.id}>
                      <div className="cart-emoji">🛍️</div>
                      <div className="cart-item-info">
                        <b>{item.product_name}</b>
                        <small>{money(item.unit_price)} each · Qty {item.quantity}</small>
                      </div>
                      <strong>{money(item.subtotal)}</strong>
                      <button className="icon-button danger" onClick={() => removeItem(item.id)}>
                        <Trash2 size={18} />
                      </button>
                    </div>
                  ))}
                </div>
                <aside className="summary">
                  <h3>Order summary</h3>
                  <div><span>Subtotal</span><b>{money(cart.total)}</b></div>
                  <div><span>Delivery</span><b>Calculated later</b></div>
                  <hr />
                  <div className="total"><span>Total</span><b>{money(cart.total)}</b></div>
                  <button className="primary-button full" disabled={cartBusy} onClick={checkout}>
                    {cartBusy ? 'Placing order...' : 'Place order'} <ArrowRight size={18} />
                  </button>
                  <small>Demo checkout. No payment is collected.</small>
                </aside>
              </div>
            )}
          </section>
        )}

        {view === 'orders' && (
          <section className="section page-section">
            <span className="eyebrow">YOUR PURCHASES</span>
            <h2>Order history</h2>
            {orders.length === 0 ? (
              <div className="empty">
                <History size={40} />
                <h3>No orders yet</h3>
                <p>Your placed orders will appear here.</p>
                <button className="primary-button" onClick={() => setView('shop')}>Start shopping</button>
              </div>
            ) : (
              <div className="orders-list">
                {orders.map(order => (
                  <article className="order-card" key={order.id}>
                    <div className="order-top">
                      <div><small>ORDER NUMBER</small><b>#{order.id}</b></div>
                      <span className="status">{order.status}</span>
                    </div>
                    {order.items.map((item, i) => (
                      <div className="order-line" key={i}>
                        <span>{item.product_name} × {item.quantity}</span>
                        <b>{money(item.unit_price * item.quantity)}</b>
                      </div>
                    ))}
                    <div className="order-total"><span>Order total</span><b>{money(order.total)}</b></div>
                  </article>
                ))}
              </div>
            )}
          </section>
        )}
      </main>

      <footer>
        <div className="footer-brand">Shop<span>Sphere</span></div>
        <p>Everyday essentials. A simpler way to shop.</p>
        <small>© {new Date().getFullYear()} ShopSphere. Portfolio demonstration project.</small>
      </footer>

      {authOpen && (
        <div className="modal-backdrop" onClick={() => setAuthOpen(false)}>
          <section className="auth-modal" onClick={e => e.stopPropagation()}>
            <button className="modal-close" onClick={() => setAuthOpen(false)}><X /></button>
            <div className="auth-logo"><ShoppingBag size={25} /></div>
            <h2>{authMode === 'login' ? 'Welcome back' : 'Create your account'}</h2>
            <p>{authMode === 'login' ? 'Sign in to continue shopping.' : 'Join ShopSphere and start shopping.'}</p>
            <form onSubmit={submitAuth}>
              {authMode === 'register' && (
                <label>Full name
                  <input required minLength="2" value={authForm.name}
                    onChange={e => setAuthForm({ ...authForm, name: e.target.value })}
                    placeholder="Your name" />
                </label>
              )}
              <label>Email address
                <input type="email" required value={authForm.email}
                  onChange={e => setAuthForm({ ...authForm, email: e.target.value })}
                  placeholder="you@example.com" />
              </label>
              <label>Password
                <input type="password" required minLength="8" value={authForm.password}
                  onChange={e => setAuthForm({ ...authForm, password: e.target.value })}
                  placeholder="At least 8 characters" />
              </label>
              <button className="primary-button full" disabled={busy}>
                {busy ? 'Please wait...' : authMode === 'login' ? 'Sign in' : 'Create account'}
              </button>
            </form>
            <div className="auth-switch">
              {authMode === 'login' ? "Don't have an account?" : 'Already registered?'}
              <button onClick={() => setAuthMode(authMode === 'login' ? 'register' : 'login')}>
                {authMode === 'login' ? 'Create account' : 'Sign in'}
              </button>
            </div>
          </section>
        </div>
      )}
    </div>
  )
}
EOF

echo "[4/6] Creating responsive design..."

cat > src/style.css <<'EOF'
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700;800&family=Manrope:wght@400;500;600;700;800&display=swap');

:root {
  font-family: 'DM Sans', sans-serif;
  color: #172033;
  background: #f8fafc;
  font-synthesis: none;
  text-rendering: optimizeLegibility;
  --ink: #172033;
  --muted: #758096;
  --purple: #6548e8;
  --purple-dark: #4e35c9;
  --line: #e9edf3;
}
* { box-sizing: border-box; }
body { margin: 0; min-width: 320px; }
button, input { font: inherit; }
button { cursor: pointer; }
button:disabled { opacity: .55; cursor: not-allowed; }
.navbar { background: #fff; border-bottom: 1px solid var(--line); position: sticky; top: 0; z-index: 10; }
.nav-inner { max-width: 1200px; height: 76px; padding: 0 24px; margin: auto; display: flex; align-items: center; justify-content: space-between; }
.brand { display: flex; align-items: center; gap: 10px; border: 0; background: none; font-size: 23px; font-weight: 800; color: var(--ink); }
.brand-icon, .auth-logo { display: grid; place-items: center; width: 39px; height: 39px; border-radius: 12px; color: white; background: var(--purple); }
.brand-accent, .footer-brand span { color: var(--purple); }
.nav-links { display: flex; gap: 34px; }
.nav-link { background: none; border: 0; color: #687187; font-weight: 600; padding: 28px 0; }
.nav-link.active { color: var(--purple); border-bottom: 2px solid var(--purple); }
.nav-actions, .user-menu { display: flex; align-items: center; gap: 16px; }
.cart-button, .login-button { display: flex; align-items: center; gap: 8px; background: none; border: 0; color: var(--ink); font-weight: 600; }
.cart-button b { background: var(--purple); color: white; font-size: 11px; border-radius: 20px; padding: 3px 7px; }
.login-button { border: 1px solid var(--line); border-radius: 9px; padding: 10px 14px; }
.user-name { display: flex; align-items: center; gap: 6px; font-size: 14px; font-weight: 600; }
.icon-button { display: grid; place-items: center; border: 0; background: #f2f4f8; color: #566078; width: 36px; height: 36px; border-radius: 9px; }
.mobile-toggle { display: none; background: none; border: 0; }
.hero { max-width: 1152px; margin: 34px auto 0; border-radius: 24px; padding: 66px 7%; min-height: 390px; overflow: hidden; display: flex; align-items: center; justify-content: space-between; background: linear-gradient(115deg,#171b37,#29234e 65%,#46338b); color: white; }
.hero-content { max-width: 570px; position: relative; z-index: 1; }
.eyebrow { color: var(--purple); font-size: 11px; font-weight: 800; letter-spacing: 1.8px; }
.hero .eyebrow { color: #c5baff; }
.hero h1 { font: 800 clamp(32px,4.3vw,53px)/1.13 'Manrope',sans-serif; margin: 17px 0; letter-spacing: -1.8px; }
.hero h1 span { color: #b8a9ff; }
.hero p { color: #d2d1e2; font-size: 16px; margin-bottom: 28px; }
.primary-button { display: inline-flex; align-items: center; justify-content: center; gap: 10px; background: var(--purple); color: white; border: 0; border-radius: 10px; padding: 13px 19px; font-weight: 700; transition: .2s; }
.primary-button:hover { background: var(--purple-dark); transform: translateY(-1px); }
.hero-art { position: relative; width: 300px; height: 260px; display: grid; place-items: center; }
.hero-circle { display: grid; place-items: center; width: 210px; height: 210px; border-radius: 50%; background: linear-gradient(145deg,#8874ef,#5942b9); font-size: 105px; box-shadow: 0 25px 65px #100d2866; }
.floating-card { position: absolute; padding: 12px 16px; background: white; color: var(--ink); border-radius: 12px; box-shadow: 0 10px 35px #09091e55; font-size: 13px; font-weight: 700; }
.card-one { top: 16px; right: -5px; }
.card-two { bottom: 17px; left: -5px; }
.features { max-width: 1100px; margin: 30px auto 56px; padding: 0 24px; display: grid; grid-template-columns: repeat(3,1fr); gap: 18px; }
.features > div { background: white; border: 1px solid var(--line); border-radius: 13px; padding: 18px; display: flex; align-items: center; gap: 14px; }
.features svg { color: var(--purple); width: 25px; height: 25px; }
.features span { display: grid; gap: 4px; }
.features b { font-size: 14px; }
.features small { color: var(--muted); font-size: 12px; }
.section { max-width: 1100px; padding: 0 24px; margin: 0 auto 85px; }
.section-heading { display: flex; align-items: end; justify-content: space-between; gap: 20px; margin-bottom: 26px; }
h2 { font: 800 30px 'Manrope',sans-serif; letter-spacing: -.7px; margin: 8px 0; }
.section-heading p, .auth-modal > p { color: var(--muted); margin: 6px 0 0; font-size: 14px; }
.search-box { display: flex; align-items: center; gap: 9px; padding: 0 13px; background: white; border: 1px solid var(--line); border-radius: 10px; width: 265px; height: 44px; color: #8a91a1; }
.search-box input { border: 0; outline: 0; width: 100%; min-width: 0; }
.product-grid { display: grid; grid-template-columns: repeat(3,1fr); gap: 22px; }
.product-card { background: white; border: 1px solid var(--line); border-radius: 15px; overflow: hidden; transition: .2s; }
.product-card:hover { transform: translateY(-4px); box-shadow: 0 12px 35px #20294a12; }
.product-art { height: 170px; display: grid; place-items: center; position: relative; background: linear-gradient(140deg,#f0edff,#e9edfa); }
.product-art span { font-size: 67px; }
.product-art small { position: absolute; left: 14px; top: 13px; font-size: 9px; color: #7669b3; letter-spacing: 1.2px; font-weight: 800; }
.product-info { padding: 17px; }
.product-info h3 { margin: 0 0 7px; font-size: 16px; }
.product-info p { color: var(--muted); font-size: 12px; min-height: 32px; margin: 0 0 17px; }
.product-bottom { display: flex; justify-content: space-between; align-items: center; }
.product-bottom strong { font-size: 19px; }
.add-button { display: flex; align-items: center; gap: 4px; background: #eeeaff; color: var(--purple); border: 0; border-radius: 8px; padding: 9px 12px; font-weight: 700; }
.stock { display: block; margin-top: 12px; color: #8a91a1; font-size: 11px; }
.empty { text-align: center; padding: 60px 20px; color: var(--muted); display: grid; justify-items: center; gap: 13px; }
.empty h3 { color: var(--ink); margin: 0; }
.empty p { margin: 0; }
.page-section { min-height: 480px; padding-top: 55px; }
.cart-layout { display: grid; grid-template-columns: 1.7fr 1fr; gap: 25px; margin-top: 28px; align-items: start; }
.cart-items, .summary, .order-card { background: white; border: 1px solid var(--line); border-radius: 14px; padding: 20px; }
.cart-item { display: flex; align-items: center; gap: 15px; padding: 14px 0; border-bottom: 1px solid var(--line); }
.cart-item:last-child { border-bottom: 0; }
.cart-emoji { width: 54px; height: 54px; display: grid; place-items: center; background: #f0edff; border-radius: 10px; font-size: 25px; }
.cart-item-info { display: grid; gap: 5px; flex: 1; }
.cart-item-info small { color: var(--muted); }
.cart-item > strong { font-size: 14px; }
.danger { color: #dc4545; }
.summary h3 { margin: 0 0 22px; }
.summary > div { display: flex; justify-content: space-between; margin: 15px 0; font-size: 13px; }
.summary span { color: var(--muted); }
.summary hr { border: 0; border-top: 1px solid var(--line); }
.summary .total { font-size: 17px; color: var(--ink); }
.summary .total span { color: var(--ink); font-weight: 700; }
.full { width: 100%; margin-top: 13px; }
.summary > small { display: block; text-align: center; color: var(--muted); font-size: 11px; margin-top: 12px; }
.orders-list { display: grid; gap: 16px; margin-top: 25px; max-width: 720px; }
.order-top { display: flex; justify-content: space-between; align-items: center; padding-bottom: 14px; border-bottom: 1px solid var(--line); }
.order-top > div { display: grid; gap: 5px; }
.order-top small { color: var(--muted); font-size: 10px; letter-spacing: 1px; }
.status { color: #16845a; background: #e9f8f0; border-radius: 20px; padding: 6px 12px; font-size: 11px; font-weight: 700; text-transform: capitalize; }
.order-line, .order-total { display: flex; justify-content: space-between; padding-top: 13px; font-size: 13px; }
.order-line span { color: var(--muted); }
.order-total { border-top: 1px solid var(--line); margin-top: 14px; padding-top: 14px; font-size: 15px; }
footer { text-align: center; padding: 38px 20px; background: #171b30; color: white; }
.footer-brand { font-size: 22px; font-weight: 800; }
footer p { color: #c2c5d2; font-size: 13px; }
footer small { color: #8e94a8; font-size: 11px; }
.toast { position: fixed; z-index: 30; right: 22px; top: 90px; padding: 13px 18px; border-radius: 10px; background: #e6f8ef; color: #126c45; box-shadow: 0 5px 22px #0002; font-size: 13px; font-weight: 600; }
.toast.error { background: #fff0f0; color: #b42e2e; }
.modal-backdrop { position: fixed; inset: 0; z-index: 40; display: grid; place-items: center; padding: 20px; background: #10152699; }
.auth-modal { width: min(100%,430px); background: white; border-radius: 18px; padding: 32px; position: relative; box-shadow: 0 20px 70px #0003; }
.modal-close { position: absolute; right: 16px; top: 16px; border: 0; background: #f2f4f8; border-radius: 8px; padding: 7px; display: grid; }
.auth-logo { width: 48px; height: 48px; margin-bottom: 18px; }
.auth-modal h2 { font-size: 25px; }
.auth-modal form { display: grid; gap: 15px; margin-top: 24px; }
.auth-modal label { display: grid; gap: 7px; font-size: 12px; font-weight: 700; }
.auth-modal input { border: 1px solid #e1e5ed; border-radius: 8px; padding: 12px; outline: none; }
.auth-modal input:focus { border-color: var(--purple); }
.auth-switch { text-align: center; color: var(--muted); font-size: 12px; margin-top: 20px; }
.auth-switch button { border: 0; background: none; color: var(--purple); font-weight: 700; margin-left: 5px; }
@media (max-width: 760px) {
  .nav-inner { height: 66px; padding: 0 16px; }
  .brand { font-size: 19px; }
  .nav-links { display: none; position: absolute; top: 66px; left: 0; right: 0; background: white; padding: 10px 20px; border-bottom: 1px solid var(--line); }
  .nav-links.open { display: grid; gap: 0; }
  .nav-link { text-align: left; padding: 14px 0; }
  .mobile-toggle { display: grid; place-items: center; }
  .user-name { display: none; }
  .nav-actions { gap: 9px; }
  .cart-button span { display: none; }
  .login-button { padding: 9px; font-size: 12px; }
  .hero { margin: 15px 12px 0; padding: 43px 25px; min-height: 360px; }
  .hero-art { display: none; }
  .features { grid-template-columns: 1fr; gap: 10px; margin: 23px auto 43px; }
  .section-heading { align-items: stretch; flex-direction: column; }
  .search-box { width: 100%; }
  .product-grid { grid-template-columns: repeat(2,minmax(0,1fr)); gap: 12px; }
  .product-art { height: 130px; }
  .product-art span { font-size: 53px; }
  .product-info { padding: 12px; }
  .product-info h3 { font-size: 14px; }
  .product-info p { min-height: 42px; }
  .product-bottom strong { font-size: 15px; }
  .add-button { padding: 8px; font-size: 12px; }
  .cart-layout { grid-template-columns: 1fr; }
  .cart-item { gap: 9px; }
  .cart-emoji { width: 42px; height: 42px; }
  .cart-item > strong { font-size: 12px; }
}
@media (max-width: 390px) {
  .product-grid { grid-template-columns: 1fr; }
}
EOF

echo "[5/6] Creating production Nginx configuration..."

mkdir -p deploy

cat > deploy/nginx.conf <<'EOF'
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location /api/ {
        proxy_pass http://backend:8000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /health {
        proxy_pass http://backend:8000/health;
    }

    location /docs {
        proxy_pass http://backend:8000/docs;
    }

    location /openapi.json {
        proxy_pass http://backend:8000/openapi.json;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

echo "[6/6] Installing packages and building frontend..."

npm install
npm run build

echo
echo "======================================"
echo " ShopSphere frontend build successful"
echo "======================================"
echo "Production build: $FRONTEND/dist"
echo "Development URL: http://YOUR_EC2_PUBLIC_IP:5173"
echo "Starting Vite development server..."
echo "======================================"

exec npm run dev -- --host 0.0.0.0
