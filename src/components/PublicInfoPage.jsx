import { useEffect } from 'react'

const CONTACT_EMAIL = 'hello@trovefinds.co.uk'

const content = {
  privacy: {
    title: 'Privacy policy',
    updated: '2 August 2026',
    sections: [
      ['What RooBin collects', [
        'Your email address, authentication identifiers, display name and app preferences.',
        'Team membership, roles, matches, fines, subscriptions, payments and invitations that you or your team create.',
        'Team logos you choose to upload, security and audit events, and limited technical logs needed to operate and protect the service.',
      ]],
      ['How we use information', [
        'To authenticate you, provide shared team features, send requested security and invitation emails, prevent abuse, investigate faults and meet legal obligations.',
        'RooBin does not sell personal information, show behavioural advertising or track you across other companies’ apps or websites.',
      ]],
      ['Who processes information', [
        'RooBin uses Supabase for authentication, database and file storage; Resend for transactional email; and Vercel for web hosting. Apple or Google may process authentication data if you choose their sign-in service.',
        'Public fixture information may be imported from publicly available RackEm pages when a team administrator requests it. RooBin is not affiliated with RackEm.',
      ]],
      ['How information is protected', [
        'RooBin uses access controls, encrypted HTTPS connections, server-side authorisation, short-lived verification codes and restricted administrative operations. No internet service can guarantee absolute security, so please report suspected unauthorised access promptly.',
      ]],
      ['Retention and deletion', [
        'Operational logs are normally retained for up to 30 days and security audit events for up to 12 months, unless a longer period is needed to investigate abuse or meet a legal obligation.',
        'You can permanently delete your account inside RooBin. Personal information is removed. Historic shared team ledger entries may be retained with your identity replaced by a random sport-themed alias so team financial records remain accurate.',
        'Where you are the only member of a team, deleting your account also permanently deletes that team and its history. If other members remain, you may need to transfer captaincy first.',
      ]],
      ['Your choices', [
        'You can update your display name, sign out, leave eligible teams and initiate immediate permanent account deletion in the app.',
        'Depending on applicable law, you may ask to access, correct, erase, restrict or object to use of your personal information. You may also raise a concern with your data-protection authority.',
      ]],
      ['Controller and contact', [`Andy Thomas, operator of RooBin, is the data controller. Email ${CONTACT_EMAIL} for privacy questions or requests.`]],
    ],
  },
  support: {
    title: 'RooBin support',
    updated: '2 August 2026',
    intro: 'Help with signing in, teams, matches, fines, subscriptions or account access.',
    sections: [
      ['Contact support', [
        `Email ${CONTACT_EMAIL}. Include the team name and a short description of the problem, but never send a sign-in code, team unlock code or authentication link.`,
      ]],
      ['Account deletion', [
        'In the iPhone app, open Settings, choose Delete account, then follow the verification and confirmation steps shown in the app.',
        `If you cannot access the app, email ${CONTACT_EMAIL} from the address registered to your account. We will verify the request before taking action.`,
        'Deleting an account is permanent. All personal information will be removed. Shared historic team records may remain under a random sport-themed alias.',
      ]],
      ['Security', [
        `Report suspected unauthorised access to ${CONTACT_EMAIL}. RooBin support will never ask for your one-time sign-in code or team unlock code.`,
      ]],
    ],
  },
  terms: {
    title: 'Terms of use',
    updated: '2 August 2026',
    sections: [
      ['Using RooBin', [
        'You must provide accurate account information, protect access to your email account and use RooBin only for lawful team administration.',
        'Team captains and authorised members control team records. They are responsible for entering accurate fines, subscriptions, payments, fixtures and membership information.',
      ]],
      ['Acceptable content', [
        'Do not upload or enter unlawful, abusive, discriminatory, misleading or rights-infringing content. Do not attempt to access another team without authorisation or interfere with the security or availability of RooBin.',
      ]],
      ['Money and records', [
        'RooBin records team fines, subscriptions and payment status but does not collect or transfer money. Teams remain responsible for agreeing, checking and settling their own records.',
      ]],
      ['Availability and changes', [
        'We work to keep RooBin secure and available, but service may occasionally be interrupted for maintenance or events outside our control. Features and these terms may change; material changes will be communicated where appropriate.',
      ]],
      ['Ending use', [
        'You may stop using RooBin and delete your account at any time. We may restrict access needed to protect users, investigate misuse or comply with law.',
      ]],
      ['Contact', [`Questions about these terms can be sent to ${CONTACT_EMAIL}.`]],
    ],
  },
}

export default function PublicInfoPage({ page }) {
  const document = content[page] ?? content.support

  useEffect(() => {
    window.document.title = `${document.title} | RooBin`
  }, [document.title])

  return (
    <main className="min-h-screen bg-zinc-950 px-4 py-8 text-zinc-200">
      <article className="mx-auto max-w-2xl overflow-hidden rounded-3xl border border-zinc-800 bg-zinc-900 shadow-2xl">
        <header className="border-b border-zinc-800 bg-black px-6 py-6 sm:px-10">
          <img src="/images/roo-bin-banner-transparent.png" alt="RooBin" className="h-20 w-full object-contain" />
          <h1 className="mt-5 text-3xl font-bold text-white">{document.title}</h1>
          {document.intro && <p className="mt-3 text-zinc-300">{document.intro}</p>}
          <p className="mt-2 text-sm text-zinc-500">Last updated {document.updated}</p>
        </header>
        <div className="space-y-8 px-6 py-8 sm:px-10">
          {document.sections.map(([heading, paragraphs]) => (
            <section key={heading}>
              <h2 className="text-xl font-bold text-amber-400">{heading}</h2>
              {paragraphs.map(paragraph => (
                <p key={paragraph} className="mt-3 leading-7 text-zinc-300">{paragraph}</p>
              ))}
            </section>
          ))}
        </div>
        <nav aria-label="Legal and support" className="flex flex-wrap gap-x-5 gap-y-2 border-t border-zinc-800 px-6 py-5 text-sm sm:px-10">
          <a className="text-amber-400 hover:text-amber-300" href="/privacy">Privacy</a>
          <a className="text-amber-400 hover:text-amber-300" href="/support">Support and deletion</a>
          <a className="text-amber-400 hover:text-amber-300" href="/terms">Terms</a>
          <a className="text-zinc-400 hover:text-white" href="/">Open RooBin</a>
        </nav>
      </article>
    </main>
  )
}
