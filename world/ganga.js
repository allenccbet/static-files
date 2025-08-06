document.addEventListener("DOMContentLoaded", function () {
  const _0x5893cb = document.querySelectorAll(".area-container");
  const _0x442508 = new IntersectionObserver(_0x273648 => {
    _0x273648.forEach(_0x6df345 => {
      if (_0x6df345.isIntersecting) {
        _0x6df345.target.classList.remove("invisible");
        _0x6df345.target.classList.add("fade-in-right");
        _0x442508.unobserve(_0x6df345.target);
      }
    });
  }, {
    'threshold': 0.5
  });
  _0x5893cb.forEach(_0x1e590d => {
    _0x442508.observe(_0x1e590d);
  });
});
window.addEventListener("load", () => {
  setTimeout(function () {
    const _0x13809c = document.getElementById("spinner");
    _0x13809c.classList.add("fade-out");
    setTimeout(() => {
      _0x13809c.style.display = "none";
    }, 0x3e8);
  }, 0x12c);
});
function validateDomain() {
  const _0x219752 = [
    "gangagames.com",
    "gangagames.in",
    "gangagames.win",
    "gangagame.in",
    "ganga1.in",
    "ganga2.in",
    "ganga3.in",
    "ganga4.in",
    "ganga5.in",
    "ganga6.in",
    "ganga7.in",
    "ganga8.in",
    "ganga9.in"
  ];
  const _0x10c088 = document.getElementById("searchInput").value.trim();
  let _0x567d9e = '';
  let _0x48da90 = false;
  try {
    const _0x3794a7 = new URL(_0x10c088);
    const _0x4040eb = _0x3794a7.hostname;
    _0x48da90 = _0x219752.some(_0x35eadb => _0x4040eb === _0x35eadb);
    if (_0x48da90) {
      _0x567d9e = "Verified domain <i class=\"fa-regular text-green-500 fa-circle-check\"></i>";
    } else {
      _0x567d9e = "Fake platform domain <i class=\"fa-regular text-red-500 fa-circle-xmark\"></i>";
    }
  } catch (_0x2f84e1) {
    _0x567d9e = _0x219752.includes(_0x10c088.trim().toLowerCase()) ? "Verified domain <i class=\"fa-regular text-green-500 fa-circle-check\"></i>" : "Fake platform domain <i class=\"fa-regular text-red-500 fa-circle-xmark\"></i>";
  }
  document.getElementById("popupMessage").innerHTML = _0x567d9e;
  document.getElementById("popup").classList.add("active");
  document.querySelector(".popup-box").classList.add("active");
}
function closePopup() {
  document.getElementById("popup").classList.remove('active');
  document.querySelector(".popup-box").classList.remove("active");
}
function redirectToDomain(_0x56fa5b) {
  const _0x2e7e7a = _0x56fa5b.innerText.trim();
  window.open(`https://${_0x2e7e7a}/#/register?invitationCode=66152366726`, "_blank");
}
const scrollButton = document.getElementById("scrollbtn");
const targetSection = document.getElementById("tar");
scrollButton.addEventListener("click", () => {
  targetSection.scrollIntoView({
    'behavior': "smooth"
  });
});
