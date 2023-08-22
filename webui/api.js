import express from 'express'

const router = express.Router()

router.post('/nixosConfig', (req, res) => {
  const homestakerConfig = req.body.homestakeros
  const hostname = homestakerConfig.localization.hostname
  console.log(`echo '${JSON.stringify(homestakerConfig)}' | nix run .#buidl -- -n '${hostname}' -b homestakeros`)
  res.json({ status: 'ok' })
})

export default router
