document.addEventListener('DOMContentLoaded', () => {
    const hamburger = document.querySelector('.hamburger');
    const nav = document.querySelector('.nav');
    const body = document.body;

    if (hamburger && nav) {
        hamburger.addEventListener('click', () => {
            const isOpen = nav.classList.toggle('open');
            hamburger.innerHTML = isOpen ? '&#10005;' : '&#9776;';
            body.style.overflow = isOpen ? 'hidden' : '';
        });

        nav.querySelectorAll('a[href]').forEach(link => {
            link.addEventListener('click', () => {
                nav.classList.remove('open');
                hamburger.innerHTML = '&#9776;';
                body.style.overflow = '';
            });
        });
    }

    // Pricing toggle
    const toggleBtns = document.querySelectorAll('.toggle-btn');
    const allMonthlyPrices = document.querySelectorAll('.price-monthly');
    const allAnnualPrices = document.querySelectorAll('.price-annually');

    toggleBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            toggleBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            const billing = btn.dataset.billing;
            const showMonthly = billing === 'monthly';

            allMonthlyPrices.forEach(el => el.classList.toggle('hidden', !showMonthly));
            allAnnualPrices.forEach(el => el.classList.toggle('hidden', showMonthly));
        });
    });

    // Scroll animations
    const faders = document.querySelectorAll('.fade-in');
    if (faders.length) {
        const appearOnScroll = new IntersectionObserver((entries, observer) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('appear');
                    observer.unobserve(entry.target);
                }
            });
        }, {
            threshold: 0.08,
            rootMargin: '0px 0px -40px 0px'
        });

        faders.forEach(fader => appearOnScroll.observe(fader));
    }
});
