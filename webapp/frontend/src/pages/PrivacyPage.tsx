import PublicDocument from '../components/PublicDocument';

export default function PrivacyPage() {
  return (
    <PublicDocument title="Privacy Policy">
      <p>Last Updated: September 29, 2026</p>

      <section>
        <h2 className="text-xl font-semibold mb-2">1. Introduction</h2>
        <p>This Privacy Policy describes how Pallet Rack Safety handles information when you use the app.</p>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">2. Information You Enter</h2>
        <p>
          You enter account details, customers, inspections, Issues, photos, and site documents. The app stores a
          hash of your password on this device, not the password itself.
        </p>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">3. Where Data Is Stored</h2>
        <p>
          Inspection data is stored on your device. When iCloud sync is on, that data also syncs to your iCloud
          account. A report goes to whoever you send it to when you share it.
        </p>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">4. Analytics</h2>
        <p>
          When Firebase is enabled, the app can send crash and usage analytics. Analytics are separate from your
          inspection data.
        </p>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">5. How Information Is Used</h2>
        <p>Information you enter is used to manage inspections and generate reports.</p>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">6. Data Security</h2>
        <p>iCloud sync uses Apple's CloudKit. No method of storage or transmission is perfectly secure.</p>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">7. Your Choices</h2>
        <p>
          You can edit or delete customers, inspections, and photos in the app. Clear All Data in Settings removes
          local data after you confirm it.
        </p>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">8. Changes to This Policy</h2>
        <p>We may update this policy. The date above changes when we do.</p>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">9. Contact</h2>
        <p>
          Email:{' '}
          <a className="text-blue-700 underline" href="mailto:support@skynet97.org">
            support@skynet97.org
          </a>
        </p>
      </section>
    </PublicDocument>
  );
}
