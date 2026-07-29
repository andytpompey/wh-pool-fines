import * as cheerio from 'cheerio'

const RACKEM_ORIGIN = 'https://www.rackemapp.com'
const REQUEST_HEADERS = {
  'User-Agent': 'RooBin RackEm fixture importer (read-only public page fetch)',
  Accept: 'text/html,application/xhtml+xml',
}

function clean(value = '') {
  return value.replace(/\s+/g, ' ').trim()
}

function assertSlug(value) {
  if (!/^[A-Za-z0-9._-]+$/.test(value ?? '')) throw new Error('Invalid RackEm league.')
  return value
}

function assertId(value) {
  if (!/^\d+$/.test(String(value ?? ''))) throw new Error('Invalid RackEm team.')
  return String(value)
}

async function fetchHtml(path) {
  const response = await fetch(`${RACKEM_ORIGIN}${path}`, {
    headers: REQUEST_HEADERS,
    signal: AbortSignal.timeout(15_000),
  })
  if (!response.ok) throw new Error(`RackEm returned ${response.status}.`)
  return response.text()
}

function parseTeamHref(href = '') {
  const match = href.match(/^\/leagues\/([^/]+)\/team\/(\d+)$/i)
  return match ? { leagueSlug: match[1], teamId: match[2] } : null
}

function parseVenueHref(href = '') {
  return href.match(/\/venue\/(\d+)$/i)?.[1] ?? null
}

function parseScore(text) {
  const match = clean(text).match(/^(\d+)\s*\|\s*(\d+)$/)
  return match ? { homeScore: Number(match[1]), awayScore: Number(match[2]) } : {}
}

function parseEnglishDate(value) {
  const match = clean(value).match(/(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$/)
  if (!match) return null
  const months = {
    january: 1, february: 2, march: 3, april: 4, may: 5, june: 6,
    july: 7, august: 8, september: 9, october: 10, november: 11, december: 12,
  }
  const month = months[match[2].toLowerCase()]
  if (!month) return null
  return `${match[3]}-${String(month).padStart(2, '0')}-${String(match[1]).padStart(2, '0')}`
}

export async function getRackemLeagues() {
  const html = await fetchHtml('/home/liveleagues')
  const $ = cheerio.load(html)
  const leagues = new Map()

  $('a[href*="/leagues/"]').each((_, element) => {
    const href = $(element).attr('href') ?? ''
    const match = href.match(/^https:\/\/www\.rackemapp\.com\/leagues\/([^/?#]+)\/?$/i)
    const name = clean($(element).text())
    if (!match || !name) return
    const card = $(element).closest('.col-sm-6')
    const days = card.find('span').map((__, span) => clean($(span).text())).get().filter(Boolean)
    leagues.set(match[1], {
      slug: match[1],
      name,
      url: `${RACKEM_ORIGIN}/leagues/${match[1]}`,
      days,
    })
  })

  return [...leagues.values()].sort((left, right) => left.name.localeCompare(right.name))
}

export async function getRackemTeams(leagueSlug) {
  const slug = assertSlug(leagueSlug)
  const html = await fetchHtml(`/leagues/${slug}/tables/all`)
  const $ = cheerio.load(html)
  const teams = new Map()

  $('a[href*="/team/"]').each((_, element) => {
    const parsed = parseTeamHref($(element).attr('href'))
    const name = clean($(element).text())
    if (!parsed || parsed.leagueSlug !== slug || !name) return
    teams.set(parsed.teamId, {
      id: parsed.teamId,
      name,
      url: `${RACKEM_ORIGIN}/leagues/${slug}/team/${parsed.teamId}`,
    })
  })

  return [...teams.values()].sort((left, right) => left.name.localeCompare(right.name))
}

export async function getRackemTeamPage(leagueSlug, seasonTeamId) {
  const slug = assertSlug(leagueSlug)
  const teamId = assertId(seasonTeamId)
  const sourceUrl = `${RACKEM_ORIGIN}/leagues/${slug}/team/${teamId}`
  const html = await fetchHtml(`/leagues/${slug}/team/${teamId}`)
  const $ = cheerio.load(html)
  const profileCard = $('h3.text-primary').first().closest('.card')
  const teamName = clean(profileCard.find('h3.text-primary').first().text())
  if (!teamName) throw new Error('RackEm team profile could not be read.')

  const divisionAnchor = profileCard.find('a[href*="/tables/"]').first()
  const venueAnchor = profileCard.find('a[href*="/venue/"]').first()
  const history = []

  $('a.link-primary.fw-bold[href*="/team/"]').each((_, element) => {
    const parsed = parseTeamHref($(element).attr('href'))
    if (!parsed || parsed.leagueSlug !== slug) return
    const seasonName = clean($(element).parent().find('.text-xs').text()).replace(/^\|\s*/, '')
    if (!seasonName) return
    history.push({
      name: seasonName,
      teamName: clean($(element).text()),
      seasonTeamId: parsed.teamId,
      url: `${RACKEM_ORIGIN}/leagues/${slug}/team/${parsed.teamId}`,
      current: parsed.teamId === teamId,
    })
  })

  const matches = []
  $('.border-top.mt-1.mb-1.p-1.w-100.mx-auto').each((_, headerElement) => {
    const header = $(headerElement)
    const matchday = clean(header.find('b').first().text())
    const date = parseEnglishDate(header.text())
    const row = header.next('.row.pb-3.mx-0')
    if (!matchday || !date || !row.length) return

    const teamAnchors = row.find('a[href*="/team/"]').toArray()
      .map(element => {
        const parsed = parseTeamHref($(element).attr('href'))
        return parsed ? { id: parsed.teamId, name: clean($(element).text()) } : null
      })
      .filter(Boolean)
    if (teamAnchors.length !== 2) return

    const venueLink = row.find('a[href*="/venue/"]').first()
    const scoreButton = row.find('button[onclick*="GetScorecard"]').first()
    const scorecardId = scoreButton.attr('onclick')?.match(/GetScorecard\('[^']+',(\d+)\)/)?.[1] ?? null
    const score = parseScore(scoreButton.text())
    const homeTeam = teamAnchors[0]
    const awayTeam = teamAnchors[1]
    const sourceIdentity = scorecardId
      ? `rackem:${slug}:scorecard:${scorecardId}`
      : `rackem:${teamId}:${date}:${matchday}:${homeTeam.id}:${awayTeam.id}`

    matches.push({
      sourceIdentity,
      scorecardId,
      matchday,
      date,
      homeTeam,
      awayTeam,
      venue: venueLink.length ? {
        id: parseVenueHref(venueLink.attr('href')),
        name: clean(venueLink.text()),
      } : null,
      status: scorecardId ? 'completed' : 'scheduled',
      ...score,
    })
  })

  const currentSeason = history.find(season => season.current) ?? null
  return {
    leagueSlug: slug,
    seasonTeamId: teamId,
    sourceUrl,
    teamName,
    division: clean(divisionAnchor.text()) || null,
    venue: venueAnchor.length ? {
      id: parseVenueHref(venueAnchor.attr('href')),
      name: clean(venueAnchor.text()),
    } : null,
    currentSeason,
    seasons: history,
    matches,
  }
}
