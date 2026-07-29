import { supabase } from './supabase'

export const TEAM_LOGO_INPUT_TYPES = ['image/jpeg', 'image/png', 'image/webp']
export const TEAM_LOGO_MAX_INPUT_BYTES = 5 * 1024 * 1024
export const TEAM_LOGO_MAX_OUTPUT_BYTES = 1024 * 1024
export const TEAM_LOGO_WIDTH = 1200
export const TEAM_LOGO_HEIGHT = 400

function loadImage(file) {
  return new Promise((resolve, reject) => {
    const image = new Image()
    const url = URL.createObjectURL(file)
    image.onload = () => {
      URL.revokeObjectURL(url)
      resolve(image)
    }
    image.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('The selected image could not be read.'))
    }
    image.src = url
  })
}

function canvasToBlob(canvas, quality) {
  return new Promise((resolve, reject) => {
    canvas.toBlob(blob => {
      if (blob) resolve(blob)
      else reject(new Error('The team logo could not be resized.'))
    }, 'image/webp', quality)
  })
}

export function validateTeamLogo(file) {
  if (!file) throw new Error('Choose an image first.')
  if (!TEAM_LOGO_INPUT_TYPES.includes(file.type)) {
    throw new Error('Use a JPG, PNG, or WebP image.')
  }
  if (file.size > TEAM_LOGO_MAX_INPUT_BYTES) {
    throw new Error('The selected image must be 5 MB or smaller.')
  }
}

export async function prepareTeamLogo(file) {
  validateTeamLogo(file)
  const image = await loadImage(file)
  const canvas = document.createElement('canvas')
  canvas.width = TEAM_LOGO_WIDTH
  canvas.height = TEAM_LOGO_HEIGHT
  const context = canvas.getContext('2d')
  if (!context) throw new Error('Image resizing is not supported by this browser.')

  const scale = Math.min(TEAM_LOGO_WIDTH / image.naturalWidth, TEAM_LOGO_HEIGHT / image.naturalHeight)
  const width = Math.max(1, Math.round(image.naturalWidth * scale))
  const height = Math.max(1, Math.round(image.naturalHeight * scale))
  const x = Math.round((TEAM_LOGO_WIDTH - width) / 2)
  const y = Math.round((TEAM_LOGO_HEIGHT - height) / 2)

  context.clearRect(0, 0, TEAM_LOGO_WIDTH, TEAM_LOGO_HEIGHT)
  context.imageSmoothingEnabled = true
  context.imageSmoothingQuality = 'high'
  context.drawImage(image, x, y, width, height)

  for (const quality of [0.9, 0.8, 0.7, 0.6]) {
    const blob = await canvasToBlob(canvas, quality)
    if (blob.size <= TEAM_LOGO_MAX_OUTPUT_BYTES) return blob
  }
  throw new Error('The resized logo is still too large. Try a simpler image.')
}

export async function uploadTeamLogo({ teamId, file }) {
  if (!teamId) throw new Error('Team is required.')
  const logo = await prepareTeamLogo(file)
  const path = `${teamId}/logo.webp`
  const { error } = await supabase.storage
    .from('team-logos')
    .upload(path, logo, { contentType: 'image/webp', upsert: true, cacheControl: '3600' })
  if (error) throw error

  const { data } = supabase.storage.from('team-logos').getPublicUrl(path)
  return `${data.publicUrl}?v=${Date.now()}`
}
