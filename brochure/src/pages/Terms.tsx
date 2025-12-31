export default function Terms() {
  return (
    <div className="legal-page">
      <h1>Terms of Use</h1>
      <p className="legal-updated">Last updated: December 30, 2025</p>

      <section>
        <h2>1. Acceptance of Terms</h2>
        <p>
          By downloading, installing, or using DataBar ("the App"), you agree to
          be bound by these Terms of Use. If you do not agree to these terms, do
          not use the App.
        </p>
      </section>

      <section>
        <h2>2. Description of Service</h2>
        <p>
          DataBar is a macOS menu bar application that displays real-time user
          count data from Google Analytics. The App requires you to authenticate
          with your Google account to access your Google Analytics data.
        </p>
      </section>

      <section>
        <h2>3. Google Account & Data Access</h2>
        <p>
          To use DataBar, you must sign in with a Google account that has access
          to Google Analytics properties. The App requests read-only access to
          your Google Analytics data. DataBar does not store your Google
          credentials—authentication is handled directly by Google.
        </p>
      </section>

      <section>
        <h2>4. User Responsibilities</h2>
        <p>You agree to:</p>
        <ul>
          <li>Use the App only for lawful purposes</li>
          <li>Not attempt to reverse engineer, modify, or distribute the App</li>
          <li>Maintain the security of your Google account credentials</li>
          <li>
            Comply with Google's Terms of Service when accessing Google Analytics
            data through the App
          </li>
        </ul>
      </section>

      <section>
        <h2>5. Disclaimer of Warranties</h2>
        <p>
          The App is provided "as is" without warranty of any kind, express or
          implied. We do not guarantee that the App will be error-free,
          uninterrupted, or meet your specific requirements.
        </p>
      </section>

      <section>
        <h2>6. Limitation of Liability</h2>
        <p>
          To the maximum extent permitted by law, the developers of DataBar shall
          not be liable for any indirect, incidental, special, consequential, or
          punitive damages arising from your use of the App.
        </p>
      </section>

      <section>
        <h2>7. Changes to Terms</h2>
        <p>
          We reserve the right to modify these Terms of Use at any time. Continued
          use of the App after changes constitutes acceptance of the new terms.
        </p>
      </section>

      <section>
        <h2>8. Contact</h2>
        <p>
          If you have questions about these Terms, please open an issue on our{' '}
          <a
            href="https://github.com/sammarks/DataBar/issues"
            target="_blank"
            rel="noopener noreferrer"
          >
            GitHub repository
          </a>
          .
        </p>
      </section>
    </div>
  )
}
