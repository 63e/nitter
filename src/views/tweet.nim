import strutils, sequtils
import karax/[karaxdsl, vdom, vstyles]

import renderutils
import ../types, ../utils, ../formatters

proc renderHeader(tweet: Tweet): VNode =
  buildHtml(tdiv):
    if tweet.retweet.isSome:
      tdiv(class="retweet"):
        span: icon "retweet", get(tweet.retweet).by & " retweeted"

    if tweet.pinned:
      tdiv(class="pinned"):
        span: icon "pin", "Pinned Tweet"

    tdiv(class="tweet-header"):
      a(class="tweet-avatar", href=("/" & tweet.profile.username)):
        genImg(tweet.profile.getUserpic("_bigger"), class="avatar")

      tdiv(class="tweet-name-row"):
        tdiv(class="fullname-and-username"):
          linkUser(tweet.profile, class="fullname")
          linkUser(tweet.profile, class="username")

        span(class="tweet-date"):
          a(href=getLink(tweet), title=tweet.getTime()):
            text tweet.shortTime

proc renderAlbum(tweet: Tweet): VNode =
  let
    groups = if tweet.photos.len < 3: @[tweet.photos]
             else: tweet.photos.distribute(2)
    class = if groups.len == 1 and groups[0].len == 1: "single-image"
            else: ""

  buildHtml(tdiv(class=("attachments " & class))):
    for i, photos in groups:
      let margin = if i > 0: ".25em" else: ""
      let flex = if photos.len > 1 or groups.len > 1: "flex" else: "block"
      tdiv(class="gallery-row", style={marginTop: margin}):
        for photo in photos:
          tdiv(class="attachment image"):
            a(href=getSigUrl(photo & "?name=orig", "pic"), class="still-image",
              target="_blank", style={display: flex}):
              genImg(photo)

proc isPlaybackEnabled(prefs: Prefs; video: Video): bool =
  case video.playbackType
  of mp4: prefs.mp4Playback
  of m3u8, vmap: prefs.hlsPlayback

proc renderVideoDisabled(video: Video): VNode =
  buildHtml(tdiv):
    img(src=video.thumb.getSigUrl("pic"))
    tdiv(class="video-overlay"):
      case video.playbackType
      of mp4:
        p: text "mp4 playback disabled in preferences"
      of m3u8, vmap:
        p: text "hls playback disabled in preferences"

proc renderVideo(video: Video; prefs: Prefs): VNode =
  buildHtml(tdiv(class="attachments")):
    tdiv(class="gallery-video"):
      tdiv(class="attachment video-container"):
        if prefs.isPlaybackEnabled(video):
          let thumb = video.thumb.getSigUrl("pic")
          let source = video.url.getSigUrl("video")
          case video.playbackType
          of mp4:
            if prefs.muteVideos:
              video(poster=thumb, controls="", muted=""):
                source(src=source, `type`="video/mp4")
            else:
              video(poster=thumb, controls=""):
                source(src=source, `type`="video/mp4")
          of m3u8, vmap:
            video(poster=thumb, data-url=source, data-autoload="false")
            verbatim "<div class=\"video-overlay\" onclick=\"playVideo(this)\">"
            verbatim "<div class=\"overlay-circle\">"
            verbatim "<span class=\"overlay-triangle\"</span></div></div>"
        else:
          renderVideoDisabled(video)

proc renderGif(gif: Gif; prefs: Prefs): VNode =
  buildHtml(tdiv(class="attachments media-gif")):
    tdiv(class="gallery-gif", style=style(maxHeight, "unset")):
      tdiv(class="attachment"):
        let thumb = gif.thumb.getSigUrl("pic")
        let url = gif.url.getSigUrl("video")
        if prefs.autoplayGifs:
          video(class="gif", poster=thumb, autoplay="", muted="", loop=""):
            source(src=url, `type`="video/mp4")
        else:
          video(class="gif", poster=thumb, controls="", muted="", loop=""):
            source(src=url, `type`="video/mp4")

proc renderPoll(poll: Poll): VNode =
  buildHtml(tdiv(class="poll")):
    for i in 0 ..< poll.options.len:
      let leader = if poll.leader == i: " leader" else: ""
      let perc = $poll.values[i] & "%"
      tdiv(class=("poll-meter" & leader)):
        span(class="poll-choice-bar", style=style(width, perc))
        span(class="poll-choice-value"): text perc
        span(class="poll-choice-option"): text poll.options[i]
    span(class="poll-info"):
      text $poll.votes & " votes • " & poll.status

proc renderCardImage(card: Card): VNode =
  buildHtml(tdiv(class="card-image-container")):
    tdiv(class="card-image"):
      img(src=getSigUrl(get(card.image), "pic"))
      if card.kind == player:
        tdiv(class="card-overlay"):
          tdiv(class="overlay-circle"):
            span(class="overlay-triangle")

proc renderCardContent(card: Card): VNode =
  buildHtml(tdiv(class="card-content")):
    h2(class="card-title"): text card.title
    p(class="card-description"): text card.text
    span(class="card-destination"): text card.dest

proc renderCard(card: Card; prefs: Prefs): VNode =
  const largeCards = {summaryLarge, liveEvent, promoWebsite, promoVideo}
  let large = if card.kind in largeCards: " large" else: ""
  let url = replaceUrl(card.url, prefs)

  buildHtml(tdiv(class=("card" & large))):
    if card.video.isSome:
      tdiv(class="card-container"):
        renderVideo(get(card.video), prefs)
        a(class="card-content-container", href=url):
          renderCardContent(card)
    else:
      a(class="card-container", href=url):
        if card.image.isSome:
          renderCardImage(card)
        tdiv(class="card-content-container"):
          renderCardContent(card)

proc renderStats(stats: TweetStats; views: string): VNode =
  buildHtml(tdiv(class="tweet-stats")):
    span(class="tweet-stat"): icon "comment", $stats.replies
    span(class="tweet-stat"): icon "retweet", $stats.retweets
    span(class="tweet-stat"): icon "thumbs-up", $stats.likes
    if views.len > 0:
      span(class="tweet-stat"): icon "play", views

proc renderReply(tweet: Tweet): VNode =
  buildHtml(tdiv(class="replying-to")):
    text "Replying to "
    for i, u in tweet.reply:
      if i > 0: text " "
      a(href=("/" & u)): text "@" & u

proc renderReply(quote: Quote): VNode =
  buildHtml(tdiv(class="replying-to")):
    text "Replying to "
    for i, u in quote.reply:
      if i > 0: text " "
      a(href=("/" & u)): text "@" & u

proc renderQuoteMedia(quote: Quote): VNode =
  buildHtml(tdiv(class="quote-media-container")):
    if quote.thumb.len > 0:
      tdiv(class="quote-media"):
        genImg(quote.thumb)
        if quote.badge.len > 0:
          tdiv(class="quote-badge"):
            tdiv(class="quote-badge-text"): text quote.badge
    elif quote.sensitive:
      tdiv(class="quote-sensitive"):
        icon "attention", class="quote-sensitive-icon"

proc renderQuote(quote: Quote; prefs: Prefs): VNode =
  if not quote.available:
    return buildHtml(tdiv(class="quote unavailable")):
      tdiv(class="unavailable-quote"):
        text "This tweet is unavailable"

  buildHtml(tdiv(class="quote")):
    a(class="quote-link", href=getLink(quote))

    if quote.thumb.len > 0 or quote.sensitive:
      renderQuoteMedia(quote)

    tdiv(class="fullname-and-username"):
      linkUser(quote.profile, class="fullname")
      linkUser(quote.profile, class="username")

    if quote.reply.len > 0:
      renderReply(quote)

    tdiv(class="quote-text"):
      verbatim linkifyText(quote.text, prefs)

    if quote.hasThread:
      a(class="show-thread", href=getLink(quote)):
        text "Show this thread"

proc renderTweet*(tweet: Tweet; prefs: Prefs; class="";
                  index=0; total=(-1); last=false): VNode =
  var divClass = class
  if index == total or last:
    divClass = "thread-last " & class

  if not tweet.available:
    return buildHtml(tdiv(class=divClass)):
      tdiv(class="status-el unavailable"):
        tdiv(class="unavailable-box"):
          text "This tweet is unavailable"

  buildHtml(tdiv(class=divClass)):
    tdiv(class="status-el"):
      tdiv(class="status-body"):
        var views = ""
        renderHeader(tweet)

        if index == 0 and tweet.reply.len > 0:
          renderReply(tweet)

        tdiv(class="status-content media-body"):
          verbatim linkifyText(tweet.text, prefs)

        if tweet.quote.isSome:
          renderQuote(tweet.quote.get(), prefs)

        if tweet.card.isSome:
          renderCard(tweet.card.get(), prefs)
        elif tweet.photos.len > 0:
          renderAlbum(tweet)
        elif tweet.video.isSome:
          renderVideo(tweet.video.get(), prefs)
          views = tweet.video.get().views
        elif tweet.gif.isSome:
          renderGif(tweet.gif.get(), prefs)
        elif tweet.poll.isSome:
          renderPoll(tweet.poll.get())

        if not prefs.hideTweetStats:
          renderStats(tweet.stats, views)

        if tweet.hasThread and "timeline" in class:
          a(class="show-thread", href=getLink(tweet)):
            text "Show this thread"