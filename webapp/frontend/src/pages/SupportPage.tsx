import PublicDocument from '../components/PublicDocument';

export default function SupportPage() {
  return (
    <PublicDocument title="Support">
      <p>
        Pallet Rack Safety records storage-rack inspections: customers, issues, photos, site equipment, and PDF or
        CSV reports.
      </p>
      <p>
        Email{' '}
        <a className="text-blue-700 underline" href="mailto:support@skynet97.org">
          support@skynet97.org
        </a>{' '}
        for help with the iOS app.
      </p>
      <p>
        Email{' '}
        <a className="text-blue-700 underline" href="mailto:bugs@skynet97.org">
          bugs@skynet97.org
        </a>{' '}
        to report a bug. Include the device model, iOS version, and the app version from Settings → About.
      </p>
      <p>Inspection data stays on the device and, when iCloud sync is on, in that Apple ID’s iCloud account.</p>
    </PublicDocument>
  );
}
