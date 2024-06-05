fs = require 'fs'
{ DOMParser } = require 'xmldom'
{Vector} = require './vector'

parsePathCommands = (d) ->
  points = []
  regex = / ?([MmLlCcVvZz])? ?(-?\d*\.?\d+(?:e[-+]?\d+)?),(-?\d*\.?\d+(?:e[-+]?\d+)?)/g
  prev = null
  command = null

  while match = regex.exec(d)
    if match[1]
      command = match[1]
    x = parseFloat(match[2]) * 10
    y = parseFloat(match[3]) * 10
    if prev && command && command.toLowerCase() == command
      x += prev.x
      y += prev.y

    x = 0 if x < 0
    x = 2500 if x > 2500
    y = 0 if y < 0
    y = 2500 if y > 2500

    point = new Vector(Math.round(x), Math.round(y))
    if prev && point.equals(prev)
      continue
    points.push point
    prev = point
  points

convertMap = (svgContent) ->
  svgContent = fs.readFileSync("#{__dirname}/map.svg", 'utf8')
  doc = new DOMParser().parseFromString(svgContent, 'application/xml')
  paths = doc.getElementsByTagName('path')
  segments = []
  for path in paths
    segments.push parsePathCommands(path.getAttribute('d'))
  segments

exports.convertMap = convertMap
