import express from 'express'
import cors from 'cors'

const app = express()
app.use(express.json())
app.use(cors())

app.post('/api/nixosConfig', (req, res) => {
  console.log(req.body)
  const homestakerConfig = req.body.homestakeros
  const hostname = homestakerConfig.localization.hostname
  console.log(`echo '${JSON.stringify(homestakerConfig)}' | nix run .#buidl -- -n '${hostname}' -b homestakeros`)
  res.json({ hello: 'world' })
})

app.listen(8081, () => {
  console.log('API server is listening on port 8081')
})
