export default function Privacy() {
  return (
    <div className="legal-page">
      <h1>Privacy Policy</h1>
      <p className="legal-updated">Last updated: December 30, 2025</p>

      <section>
        <h2>Overview</h2>
        <p>
          DataBar is designed with privacy in mind. We collect minimal data and
          never sell or share your personal information with third parties.
        </p>
      </section>

      <section>
        <h2>Data We Access</h2>
        <h3>Google Analytics Data</h3>
        <p>
          When you sign in with your Google account, DataBar requests read-only
          access to your Google Analytics data. This includes:
        </p>
        <ul>
          <li>List of Google Analytics accounts and properties you have access to</li>
          <li>Real-time active user count for your selected property</li>
        </ul>
        <p>
          This data is fetched directly from Google's servers and displayed in the
          App. We do not store, log, or transmit this data to any other servers.
        </p>
      </section>

      <section>
        <h2>Data We Store</h2>
        <h3>Local Preferences</h3>
        <p>DataBar stores the following data locally on your Mac:</p>
        <ul>
          <li>Your selected Google Analytics property ID</li>
          <li>Your preferred refresh interval setting</li>
          <li>Authentication tokens (managed securely by macOS Keychain)</li>
        </ul>
        <p>
          This data never leaves your device and is not transmitted to any external
          servers.
        </p>
      </section>

      <section>
        <h2>Telemetry & Analytics</h2>
        <p>
          DataBar may collect anonymous crash reports and usage analytics to help
          improve the App. This data does not include any personal information or
          Google Analytics data. You can opt out of telemetry in the App's settings.
        </p>
      </section>

      <section>
        <h2>Third-Party Services</h2>
        <h3>Google Sign-In</h3>
        <p>
          DataBar uses Google Sign-In for authentication. When you sign in, you are
          subject to{' '}
          <a
            href="https://policies.google.com/privacy"
            target="_blank"
            rel="noopener noreferrer"
          >
            Google's Privacy Policy
          </a>
          . DataBar does not have access to your Google password.
        </p>

        <h3>Sparkle Updates</h3>
        <p>
          DataBar uses Sparkle to check for and install updates. Sparkle may collect
          anonymous system information (macOS version, app version) to facilitate
          updates. See the{' '}
          <a
            href="https://sparkle-project.org/"
            target="_blank"
            rel="noopener noreferrer"
          >
            Sparkle documentation
          </a>{' '}
          for details.
        </p>
      </section>

      <section>
        <h2>Data Security</h2>
        <p>
          Authentication tokens are stored securely in the macOS Keychain. All
          communication with Google's servers uses HTTPS encryption.
        </p>
      </section>

      <section>
        <h2>Your Rights</h2>
        <p>You can:</p>
        <ul>
          <li>Sign out of DataBar at any time to revoke access</li>
          <li>
            Revoke DataBar's access to your Google account via{' '}
            <a
              href="https://myaccount.google.com/permissions"
              target="_blank"
              rel="noopener noreferrer"
            >
              Google Account settings
            </a>
          </li>
          <li>Uninstall the App to remove all locally stored data</li>
        </ul>
      </section>

      <section>
        <h2>Children's Privacy</h2>
        <p>
          DataBar is not intended for use by children under 13. We do not knowingly
          collect data from children.
        </p>
      </section>

      <section>
        <h2>Changes to This Policy</h2>
        <p>
          We may update this Privacy Policy from time to time. The latest version
          will always be available on this page with the updated date.
        </p>
      </section>

      <section>
        <h2>Contact</h2>
        <p>
          If you have questions about this Privacy Policy, please open an issue on
          our{' '}
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
