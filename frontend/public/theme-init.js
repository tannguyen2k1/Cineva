(function () {
  try {
    localStorage.setItem('vueuse-color-scheme', 'dark')
    document.documentElement.classList.add('dark')
  } catch (_) {
    try {
      document.documentElement.classList.add('dark')
    } catch (__) {}
  }
})()
