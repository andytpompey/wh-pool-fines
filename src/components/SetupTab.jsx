import { useState } from 'react'
import { Btn } from '../App'
import * as db from '../lib/db'

export default function SetupTab({
  players, fineTypes, seasons, matches,
  setPlayers, setFineTypes, setSeasons, setMatches,
  currentTeam, currentTeamRole,
  onOpenProfile, onOpenTeams, onOpenTeamManagement, onSignOut, onClose,
}) {
  const [section, setSection] = useState('hub')
  const hasCurrentTeam = Boolean(currentTeam)
  const canManageTeam = currentTeamRole === 'captain' || currentTeamRole === 'admin'
  const sections = canManageTeam ? ['hub', 'account', 'data'] : ['hub', 'account']

  const handleExport = () => {
    const data = { players, fineTypes, seasons, matches, exportedAt: new Date().toISOString() }
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `white-horse-pool-fines-${new Date().toISOString().slice(0, 10)}.json`
    a.click()
    URL.revokeObjectURL(url)
  }

  const [importText, setImportText] = useState('')
  const [importError, setImportError] = useState('')
  const [importSuccess, setImportSuccess] = useState(false)
  const [importing, setImporting] = useState(false)

  const runImport = async () => {
    try {
      const data = JSON.parse(importText.trim())
      if (!Array.isArray(data.players) || !Array.isArray(data.fineTypes) || !Array.isArray(data.seasons) || !Array.isArray(data.matches)) {
        setImportError('Invalid format — missing required fields.')
        return
      }
      setImporting(true)
      await db.importAll(data)
      setPlayers(data.players)
      setFineTypes(data.fineTypes)
      setSeasons(data.seasons)
      setMatches(data.matches)
      setImportText('')
      setImportError('')
      setImportSuccess(true)
    } catch (e) {
      setImportError(e.message?.includes('JSON') ? 'Could not parse JSON — paste the full file contents.' : `Import failed: ${e.message}`)
    } finally {
      setImporting(false)
    }
  }

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-black/60 px-3 pb-24 pt-6 backdrop-blur-sm" onClick={onClose}>
      <div
        className="max-h-[min(80vh,42rem)] w-full max-w-lg overflow-y-auto rounded-3xl border border-zinc-700 bg-zinc-950 shadow-2xl"
        onClick={event => event.stopPropagation()}
      >
        <div className="sticky top-0 z-10 border-b border-zinc-800 bg-zinc-950/95 px-4 py-4 backdrop-blur">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-zinc-500">More</p>
              <h2 className="mt-1 text-lg font-bold text-white">Quick actions</h2>
              <p className="mt-1 text-xs text-zinc-400">Open profile, teams, and admin tools without leaving the current screen.</p>
            </div>
            <button
              type="button"
              aria-label="Close more menu"
              onClick={onClose}
              className="rounded-full border border-zinc-700 bg-zinc-900 px-3 py-1.5 text-sm font-bold text-zinc-300 transition hover:text-white"
            >
              Close
            </button>
          </div>

          <div className="mt-4 grid grid-cols-1 gap-2 sm:grid-cols-3">
            <Btn onClick={onOpenProfile} className="w-full">Profile</Btn>
            <Btn variant="outline" onClick={onOpenTeams} className="w-full">My Teams</Btn>
            {hasCurrentTeam && <Btn variant="outline" onClick={onOpenTeamManagement} className="w-full">Team Management</Btn>}
          </div>
        </div>

        <div className="space-y-3 p-4">
          <div className="rounded-2xl border border-zinc-800 bg-zinc-900 px-4 py-3">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-zinc-500">Menu</p>
                <h3 className="mt-1 text-base font-bold text-white">Profile and teams</h3>
                <p className="mt-1 text-xs text-zinc-400">Treat More as a popout hub for account, team switching, and occasional admin actions.</p>
              </div>
              {hasCurrentTeam && (
                <div className="text-right">
                  <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-zinc-500">Current team</p>
                  <p className="mt-1 text-sm font-bold text-white">{currentTeam.name}</p>
                </div>
              )}
            </div>

            {hasCurrentTeam && (
              <div className="mt-3 rounded-xl border border-zinc-800 bg-zinc-950/70 px-3 py-2 text-xs text-zinc-400">
                Team-specific seasons and fine types now live in Team Management for <span className="font-bold text-white">{currentTeam.name}</span>.
                <span className="mt-1 block">Use the selected team page for roster, invites, fines, and seasons so setup no longer duplicates those controls.</span>
              </div>
            )}
          </div>

          <div className="flex gap-1 overflow-x-auto rounded-xl bg-zinc-800 p-1">
            {sections.map(s => (
              <button
                key={s}
                onClick={() => setSection(s)}
                className={`flex-1 rounded-lg py-2 text-xs font-bold capitalize transition-all ${section === s ? 'bg-amber-500 text-zinc-900' : 'text-zinc-400 hover:text-white'}`}
              >
                {s}
              </button>
            ))}
          </div>

          {section === 'hub' && (
            <div className="space-y-3">
              <div className="grid grid-cols-1 gap-2">
                <Btn onClick={onOpenProfile} className="w-full">Profile</Btn>
                <Btn variant="outline" onClick={onOpenTeams} className="w-full">My Teams</Btn>
                {hasCurrentTeam && <Btn variant="outline" onClick={onOpenTeamManagement} className="w-full">Open Team Management</Btn>}
                <Btn variant="ghost" onClick={onSignOut} className="w-full">Sign out</Btn>
              </div>

              <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-4 text-sm text-zinc-400">
                {canManageTeam
                  ? 'Captains and admins can jump into Team Management for configuration, while this menu keeps navigation and backup tools close at hand.'
                  : 'Team setup tools are limited to captains and admins, but your Profile and Teams pages are available here at any time.'}
              </div>

              {canManageTeam && (
                <div className="rounded-xl border border-zinc-800 bg-zinc-900/80 px-3 py-3">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-zinc-500">Admin</p>
                      <h3 className="mt-1 text-sm font-bold text-white">Team configuration</h3>
                      <p className="mt-1 text-xs text-zinc-400">Fines, seasons, roster, and invites are managed from the selected team page.</p>
                    </div>
                    <Btn size="sm" variant="outline" onClick={onOpenTeamManagement}>Open</Btn>
                  </div>
                </div>
              )}
            </div>
          )}

          {section === 'account' && (
            <div className="space-y-3">
              <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-4 text-sm text-zinc-400">
                Profile access, team switching, and sign-out stay here. Team-specific configuration now lives inside Team Management.
              </div>

              {hasCurrentTeam && (
                <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                  <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
                    <p className="text-xs font-bold uppercase tracking-wider text-zinc-400">Fines</p>
                    <h3 className="mt-1 font-bold text-white">Manage fine types from the team</h3>
                    <p className="mt-2 text-sm text-zinc-400">Add, edit, and remove {currentTeam.name}&apos;s fine types from Team Management → Fines.</p>
                    <Btn variant="outline" className="mt-3 w-full" onClick={onOpenTeamManagement}>Open Team Management</Btn>
                  </div>
                  <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
                    <p className="text-xs font-bold uppercase tracking-wider text-zinc-400">Seasons</p>
                    <h3 className="mt-1 font-bold text-white">Manage seasons from the team</h3>
                    <p className="mt-2 text-sm text-zinc-400">Create and edit {currentTeam.name}&apos;s seasons from Team Management → Seasons.</p>
                    <Btn variant="outline" className="mt-3 w-full" onClick={onOpenTeamManagement}>Open Team Management</Btn>
                  </div>
                </div>
              )}
            </div>
          )}

          {section === 'data' && (
            <div className="space-y-3">
              <div className="rounded-xl bg-zinc-800 p-3">
                <h3 className="mb-2 font-bold text-white">Export data</h3>
                <p className="mb-3 text-xs text-zinc-400">Download a JSON backup of the current app data.</p>
                <Btn onClick={handleExport} className="w-full">Export JSON backup</Btn>
              </div>

              <div className="rounded-xl bg-zinc-800 p-3">
                <h3 className="mb-2 font-bold text-white">Import data</h3>
                <p className="mb-3 text-xs text-zinc-400">Paste a full backup to overwrite the current dataset.</p>
                <textarea
                  value={importText}
                  onChange={e => setImportText(e.target.value)}
                  rows={8}
                  className="mb-2 w-full rounded-lg border border-zinc-700 bg-zinc-900 px-3 py-2 text-xs text-zinc-200"
                  placeholder="Paste JSON backup here..."
                />
                {importError && <p className="mb-2 text-xs text-red-400">{importError}</p>}
                {importSuccess && <p className="mb-2 text-xs text-emerald-400">Import complete.</p>}
                <Btn variant="danger" className="w-full" onClick={runImport} disabled={importing}>{importing ? 'Importing...' : 'Import JSON (overwrite all data)'}</Btn>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
