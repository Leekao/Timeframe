cv = require './node-opencv'
fs = require 'fs'
moment = require 'moment'
async = require 'async'
{format} = require 'util'
mime = require 'mime'
gm = require('gm').subClass
  imageMagick: true

express = require 'express'
compress = require 'compression'
app = express()
app.get '/', (req, res) ->
  #res.set 'Content-Type', 'text/html'
  res.sendFile '/projects/timeframe/player.html'

app.get '/check_image/:img', (req, res) ->
  send_closest parseInt(req.params.img), res

send_closest = (img, res) ->
  console.log('checking ',img)
  if fs.existsSync("/img/#{img}.jpg")
    return res.send "#{img}"
  send_closest(img+1, res)

app.use compress()
app.use express.static('/img')
app.use express.static('frontend')

app.listen 3000, ->
  console.log 'app is online'

camera = new cv.VideoCapture(0)
window = new cv.NamedWindow('Video', 0)

minutes = (m) ->
  return 1000 * 60 * m

register = []

makefile = (src, cb) ->
  return cb()
  console.log(src, cb)
  data = fs.readFileSync(src).toString('base64')
  dataUri = format 'data:%s;base64,%s', mime.lookup(src), data
  fs.writeFile src+'.data', dataUri, cb  

fps = 30
delay = minutes(1)

play = (frame, cbk) ->
  window.show frame
  window.blockingWaitKey(0, 1000/fps)
  return cbk()

convert_img = (c, cb) ->
  cmd = ["/img/#{c}.jpg","-colorspace","gray","-sketch","0x20+120","/img/#{c}.jpg"]
  exec= require('child_process').execFile
  console.log cmd
  child = exec 'convert',cmd, (error, stdout, stderr) ->
    if error
      console.log '---------'
      console.error 'stderr', error, stderr
      console.log '---------'
    else 
      console.log('stdout', stdout)
      cb()

convert = (filename, cb) ->
  img_path = "/img/#{filename}.jpg"
  gm(img_path)
  .negative()
  .despeckle()
#  .despeckle()
  .edge(1.5)
  .negative()
#  .blur(0.5)
#  .normalize()
  .fill('#FFFFFF')
  .stroke('#000000',3)
  .drawRectangle(-4, -4, 354, 44)
  .stroke('#000000',0.25)
  .fill('#000000')
  .font("/windows/fonts/comic.ttf", 22)
  .drawText(4, 30, "Meanwhile, at the crocodile lair...")
  .write img_path, (err) ->
    if convert_queue.length() is 0
      convert_queue.concurrency-- unless convert_queue.concurrency < 5
    else
      convert_queue.concurrency++
    if (err)
      console.error 'Error'
      return cb(err)
    setImmediate ->
      makefile img_path, cb

convert_queue = async.queue convert, 10

save_counter = 0    
save_frame = (frame) ->
  ttime = new Date().valueOf()
  ttime = ttime + minutes(0.1)
  img_path = "/img/#{save_counter}.jpg"
  console.log 'saving ',img_path
  frame.save img_path
  register.push "#{ttime}.jpg"
  convert_queue.push save_counter++
  return

capture = () ->
  camera.read (err, frame) ->
    if (err) 
      console.log(err)
      return
    if frame.size()[0] > 0 and frame.size()[1] > 0
      save_frame frame

run_at_fps = (func, fps) ->
  fps_interval = 1000 / fps
  tthen = new Date().valueOf()
  setInterval () =>
    nnow = new Date().valueOf()
    elapsed = nnow - tthen
    return unless elapsed > fps_interval
    tthen = nnow - (elapsed % fps_interval)
    func()
  , 0

counter = 0
load = () ->
  ttime = new Date().valueOf()
  ttime = ttime - minutes(5)
  image_path = "/img/#{counter++}.jpg"
  cv.readImage image_path, (e, i) ->
    if e
      return console.log('no file ', image_path)
    return unless i.height() > 1
    play i, ->
      fs.unlink image_path, ->
        console.log 'deleted', image_path
  #setImmediate load

setTimeout ->
  console.log('starting to play')
  run_at_fps load, 30
, minutes(5)

run_at_fps capture, 30