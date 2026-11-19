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
