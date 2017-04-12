# Description:
#   A way to interact with the Google Images API.
#
# Configuration:
#  ソース内部の{GoogleApiKey}と{CustomSearchID}を設定する
#
# Original source:
#   https://github.com/hubot-scripts/hubot-google-images

module.exports = (robot) ->

  robot.respond /(.+)を(みせて|見せて)/i, (msg) ->
    imageMe msg, msg.match[1], (url) ->
      msg.send "これですわ！" , url

  # 未使用
  # 
  # robot.respond /(うごいて|動いて)(る|いる)(.+)を(みせて|見せて)/i, (msg) ->
  #   imageMe msg, msg.match[3], true, (url) ->
  #     msg.send "これですわ！" , url

  # pro feature, not added to docs since you can't conditionally document commands
  # 
  # ↓たぶんメンション付けなくても反応するようになるやつ
  if process.env.HUBOT_GOOGLE_IMAGES_HEAR?
    robot.hear /^(image|img) me (.+)/i, (msg) ->
      imageMe msg, msg.match[2], (url) ->
        msg.send url

    robot.hear /^animate me (.+)/i, (msg) ->
      imageMe msg, msg.match[1], true, (url) ->
        msg.send url

  robot.respond /(?:mo?u)?sta(?:s|c)h(?:e|ify)?(?: me)? (.+)/i, (msg) ->
    if not process.env.HUBOT_MUSTACHIFY_URL?
      msg.send "Sorry, the Mustachify server is not configured."
        , "http://i.imgur.com/BXbGJ1N.png"
      return
    mustacheBaseUrl =
      process.env.HUBOT_MUSTACHIFY_URL?.replace(/\/$/, '')
    mustachify = "#{mustacheBaseUrl}/rand?src="
    imagery = msg.match[1]

    if imagery.match /^https?:\/\//i
      encodedUrl = encodeURIComponent imagery
      msg.send "#{mustachify}#{encodedUrl}"
    else
      imageMe msg, imagery, false, true, (url) ->
        encodedUrl = encodeURIComponent url
        msg.send "#{mustachify}#{encodedUrl}"

imageMe = (msg, query, animated, faces, cb) ->
  cb = animated if typeof animated == 'function'
  cb = faces if typeof faces == 'function'
  googleCseId = '{CustomSearchID}';
  if googleCseId
    # Using Google Custom Search API
    googleApiKey = '{GoogleApiKey}';
    if !googleApiKey
      msg.robot.logger.error "Missing environment variable HUBOT_GOOGLE_CSE_KEY"
      msg.send "Missing server environment variable HUBOT_GOOGLE_CSE_KEY."
      return
    q =
      q: query,
      searchType:'image',
      safe: process.env.HUBOT_GOOGLE_SAFE_SEARCH || 'high',
      fields:'items(link)',
      cx: googleCseId,
      key: googleApiKey
    if animated is true
      q.fileType = 'gif'
      q.hq = 'animated'
      q.tbs = 'itp:animated'
    if faces is true
      q.imgType = 'face'
    url = 'https://www.googleapis.com/customsearch/v1'
    msg.http(url)
      .query(q)
      .get() (err, res, body) ->
        if err
          if res.statusCode is 403
            msg.send "Daily image quota exceeded, using alternate source."
            deprecatedImage(msg, query, animated, faces, cb)
          else
            msg.send "Encountered an error :( #{err}"
          return
        if res.statusCode isnt 200
          msg.send "Bad HTTP response :( #{res.statusCode}"
          return
        response = JSON.parse(body)
        if response?.items
          image = msg.random response.items
          cb ensureResult(image.link, animated)
        else
          msg.send "Oops. I had trouble searching '#{query}'. Try later."
          ((error) ->
            msg.robot.logger.error error.message
            msg.robot.logger
              .error "(see #{error.extendedHelp})" if error.extendedHelp
          ) error for error in response.error.errors if response.error?.errors
  else
    msg.send "Google Image Search API is no longer available. " +
      "Please [setup up Custom Search Engine API](https://github.com/hubot-scripts/hubot-google-images#cse-setup-details)."
    deprecatedImage(msg, query, animated, faces, cb)

deprecatedImage = (msg, query, animated, faces, cb) ->
  Show a fallback image
  imgUrl = process.env.HUBOT_GOOGLE_IMAGES_FALLBACK ||
    'http://i.imgur.com/CzFTOkI.png'
  imgUrl = imgUrl.replace(/\{q\}/, encodeURIComponent(query))
  cb ensureResult(imgUrl, animated)

# Forces giphy result to use animated version
ensureResult = (url, animated) ->
  if animated is true
    ensureImageExtension url.replace(
      /(giphy\.com\/.*)\/.+_s.gif$/,
      '$1/giphy.gif')
  else
    ensureImageExtension url

# Forces the URL look like an image URL by adding `#.png`
ensureImageExtension = (url) ->
  if /(png|jpe?g|gif)$/i.test(url)
    url
  else
    "#{url}#.png"