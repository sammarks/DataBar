import appIcon from '/app-icon.png'

const features = [
  {
    icon: '📊',
    title: 'Real-Time Analytics',
    description: 'See your active Google Analytics users at a glance, right from your menu bar.',
  },
  {
    icon: '🏢',
    title: 'Multiple Properties',
    description: 'Monitor up to 5 GA4 properties simultaneously with custom icons and labels for each.',
  },
  {
    icon: '⚡',
    title: 'Always Visible',
    description: 'Lives in your menu bar—always accessible without cluttering your desktop.',
  },
  {
    icon: '🔄',
    title: 'Auto Refresh',
    description: 'Configurable refresh intervals keep your data current. Set it and forget it.',
  },
  {
    icon: '🔗',
    title: 'Quick Access',
    description: 'Click to jump directly to your Google Analytics dashboard.',
  },
  {
    icon: '🔐',
    title: 'Secure Sign-In',
    description: 'Sign in with your Google account. Your credentials stay safe with Google.',
  },
  {
    icon: '🍎',
    title: 'Native macOS',
    description: 'Built with SwiftUI for a fast, lightweight, native experience on macOS 13+.',
  },
]

export default function Home() {
  return (
    <div className="home">
      <section className="hero">
        <img src={appIcon} alt="DataBar" className="hero-icon" />
        <h1 className="hero-title">DataBar</h1>
        <p className="hero-tagline">
          Real-time Google Analytics in your menu bar
        </p>
        <p className="hero-description">
          A lightweight macOS app that displays your Google Analytics real-time
          user count at a glance. Monitor multiple properties simultaneously with
          custom icons—no more switching tabs.
        </p>
        <div className="hero-actions">
          <a
            href="https://github.com/sammarks/DataBar/releases"
            className="btn btn-primary"
          >
            Download for macOS
          </a>
          <a
            href="https://github.com/sammarks/DataBar"
            className="btn btn-secondary"
          >
            View on GitHub
          </a>
        </div>
        <p className="hero-requirements">Requires macOS 13.0 or later</p>
      </section>

      <section className="features">
        <h2 className="features-title">Features</h2>
        <div className="features-grid">
          {features.map((feature) => (
            <div key={feature.title} className="feature-card">
              <span className="feature-icon">{feature.icon}</span>
              <h3 className="feature-title">{feature.title}</h3>
              <p className="feature-description">{feature.description}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="cta">
        <h2 className="cta-title">Ready to try DataBar?</h2>
        <p className="cta-description">
          Download now and see your analytics at a glance.
        </p>
        <a
          href="https://github.com/sammarks/DataBar/releases"
          className="btn btn-primary"
        >
          Download Free
        </a>
      </section>
    </div>
  )
}
