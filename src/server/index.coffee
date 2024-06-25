https = require 'https'
url = require 'url'
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
selfsigned = require('selfsigned')

{Server} = require 'socket.io'
{Vector} = require './vector'
{convertMap} = require './convert_map'

certPath = path.join __dirname, '../..', 'self-signed.crt'
keyPath = path.join __dirname, '../..', 'self-signed.key'

if !fs.existsSync(certPath) || !fs.existsSync(keyPath)
  pems = selfsigned.generate null, days: 365, keySize: 2048
  fs.writeFileSync certPath, pems.cert
  fs.writeFileSync keyPath, pems.private

options =
  cert: fs.readFileSync certPath
  key: fs.readFileSync keyPath

send404 = (res) ->
  res.writeHead(404)
  res.write('404')
  res.end()
  res

code = ""
code += fs.readFileSync path.join __dirname, '..', 'client/vector.js'
code += fs.readFileSync path.join __dirname, '..', 'client/index.js'

version = crypto.createHash('md5').update(code).digest("hex")

server = https.createServer options, (req,res) ->
  path = url.parse(req.url).pathname
  path = '/index.html' if path == '/'
  fs.readFile "#{__dirname}/../client/" + path, (err, data) ->
    return send404 res if err
    ext = path.substr path.lastIndexOf( "." ) + 1
    content_type = switch ext
      when 'js' then 'text/javascript'
      when 'css' then 'text/css'
      when 'html' then 'text/html'
      when 'wav' then 'audio/x-wav'
      else
        'application/octet-stream'
    res.writeHead 200, 'Content-Type': content_type
    if path == '/index.html'
      # This is one way to cachebust the code during development
      data = data.toString('utf8').replace 'CODE_HERE', code
    res.write data
    res.end()

server.listen 4100

io = new Server(server)

console.log "Server running on https://localhost:4100"

tick = 0
map = convertMap()
bases = [
  {
    team: 1
    pos: new Vector 0, 0
    health: 333
  }
  {
    team: 2
    pos: new Vector map.width, map.height
    health: 333
  }
]

players = {}
last_seen = {}

bullets = []
boings = []
deaths = []
baseHits = []
voices = []

io.sockets.on 'connection', (client) ->
  client.lastBullet = bullets.length
  client.lastBoing = boings.length
  client.lastDeath = deaths.length
  client.lastBaseHit = baseHits.length
  client.lastVoice = voices.length

  client.emit 'map', {map}

  client.emit 'version', version

  client.on 'identity', (msg) ->
    client.identity = msg.identity
    player = players[client.identity]
    if !player
      team = (Object.keys(players).length % 2) + 1
      team = 1
      player =
        team: team
      players[client.identity] = player

    client.emit 'player', {player}

  client.on 'base_hit', (msg) ->
    baseHits.push msg
    for base in bases
      base.health--
      base.health = 333 if base.health <= 10

  client.on 'boing', (msg) ->
    boings.push msg

  client.on 'death', (msg) ->
    deaths.push msg

  client.on 'voice', (data) ->
    player = players[client.identity]
    return unless player
    voices.push
      pos: player.pos
      dir: player.dir
      owner: client.identity
      data: data

  client.on 'update', (msg) ->
    now = new Date().getTime()
    last_seen[client.id] = now

    player = players[client.identity]
    if !player
      return

    if msg.bullet
      bullet = msg.bullet
      bullet.team = player.team
      bullets.push bullet

    player.pos = Vector.load msg.pos

    others = []
    for identity, p of players
      others.push p unless identity == client.identity

    client.emit 'update',
      tick: tick
      others: others
      bullets: bullets.slice client.lastBullet
      boings: boings.slice client.lastBoing
      deaths: deaths.slice client.lastDeath
      baseHits: baseHits.slice client.lastBaseHit
      voices: voices.slice client.lastVoice
      bases: bases

    client.lastBullet = bullets.length
    client.lastBoing = boings.length
    client.lastDeath = deaths.length
    client.lastBaseHit = baseHits.length
    client.lastVoice = voices.length

  client.on 'error', ->
    console.log( "error" )

  client.on 'disconnect', ->
    console.log( "disconnect" )

setInterval(
  ->
    tick++
  16
)
