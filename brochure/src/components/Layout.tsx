import { Outlet, Link } from 'react-router-dom'
import appIcon from '/app-icon.png'

export default function Layout() {
  return (
    <div className="layout">
      <header className="header">
        <Link to="/" className="logo-link">
          <img src={appIcon} alt="DataBar" className="header-icon" />
          <span className="header-title">DataBar</span>
        </Link>
        <nav className="nav">
          <a
            href="https://github.com/sammarks/DataBar/releases"
            className="nav-link download-btn"
          >
            Download
          </a>
        </nav>
      </header>

      <main className="main">
        <Outlet />
      </main>

      <footer className="footer">
        <div className="footer-content">
          <p className="footer-copyright">
            © {new Date().getFullYear()} DataBar. All rights reserved.
          </p>
          <nav className="footer-nav">
            <Link to="/terms" className="footer-link">Terms of Use</Link>
            <Link to="/privacy" className="footer-link">Privacy Policy</Link>
            <a
              href="https://github.com/sammarks/DataBar"
              className="footer-link"
              target="_blank"
              rel="noopener noreferrer"
            >
              GitHub
            </a>
          </nav>
        </div>
      </footer>
    </div>
  )
}
