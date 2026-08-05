(function () {
  try {
    var key = 'vueuse-color-scheme'
    var value = localStorage.getItem(key)
    var dark =
      value === 'dark' ||
      (value !== 'light' && window.matchMedia('(prefers-color-scheme: dark)').matches)
    if (dark) document.documentElement.classList.add('dark')
  } catch (_) {}
})()
