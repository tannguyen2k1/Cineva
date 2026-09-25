// JS injected into the 18+ embed page. Normal HLS playback does not use these.

String seedLocalStorageJs(String videoUrl, int startSec) {
  if (startSec <= 0) return '';
  return '''
(function(){
  try {
    var key = 'rz_' + btoa(unescape(encodeURIComponent('$videoUrl'))) + '_progress';
    localStorage.setItem(key, '$startSec');
  } catch(e){}
})();
''';
}

String bootJs(int startSec) {
  return '''
(function(){
  try {
    var ld=document.getElementById('loading');
    if(ld) ld.classList.add('hide');
    var v=document.querySelector('video');
    if(v){ v.setAttribute('playsinline',''); }

    var start = $startSec;

    if (start > 0) {
      var hasSeeked = false;
      var checkIntv = setInterval(function(){
        if (hasSeeked) { clearInterval(checkIntv); return; }
        try {
          if (window.jwplayer && typeof jwplayer === 'function') {
            var p = jwplayer();
            if (p && p.getPosition && p.getDuration && p.getDuration() > 0) {
              if (Math.abs(p.getPosition() - start) < 3) {
                hasSeeked = true;
              } else if (p.getPosition() > 1) {
                p.seek(start);
                hasSeeked = true;
              }
            }
          } else {
            var vid = document.querySelector('video');
            if (vid && vid.duration > 0 && vid.currentTime > 0.5) {
              if (Math.abs(vid.currentTime - start) > 3) {
                vid.currentTime = start;
              }
              hasSeeked = true;
            }
          }
        } catch(e){}
      }, 500);
      setTimeout(function(){ clearInterval(checkIntv); }, 15000);
    }
  } catch(e){}
})();
''';
}

String safeAreaJs(double bottomPx) {
  final pad = bottomPx.ceil().clamp(0, 72);
  return '''
(function(){
  try {
    var c=document.querySelector('.jw-wrapper,.jwplayer,video');
    if(c) c.style.paddingBottom='${pad}px';
  } catch(e){}
})();
''';
}

const stopPlaybackJs = r'''
(function(){
  try {
    document.querySelectorAll('video,audio').forEach(function(m){
      try {
        m.pause();
        m.muted = true;
        m.removeAttribute('src');
        while (m.firstChild) m.removeChild(m.firstChild);
        m.load();
      } catch (e) {}
    });
    try {
      if (window.jwplayer) {
        var p = jwplayer();
        if (p) {
          if (p.pause) p.pause(true);
          if (p.stop) p.stop();
          if (p.remove) p.remove();
        }
      }
    } catch (e) {}
  } catch (e) {}
})();
''';
