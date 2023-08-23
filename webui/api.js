import express from 'express'
import fs from 'fs'

const router = express.Router()
var writable = fs.createWriteStream('pipe')

router.post('/nixosConfig', (req, res) => {
  const homestakerConfig = req.body.homestakeros
  const hostname = homestakerConfig.localization.hostname
  writable.write(`echo '${JSON.stringify(homestakerConfig)}' | nix run .#buidl -- -n '${hostname}' -b homestakeros -r\n`)
  res.json({ status: 'ok' })
})

export default router
