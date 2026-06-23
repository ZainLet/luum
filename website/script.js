document.addEventListener('DOMContentLoaded', () => {

    // ── Mobile nav ───────────────────────────────────────────────────────────
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

    // ── Header scroll state ──────────────────────────────────────────────────
    const header = document.querySelector('.header');
    if (header) {
        const onScroll = () => header.classList.toggle('scrolled', window.scrollY > 20);
        window.addEventListener('scroll', onScroll, { passive: true });
        onScroll();
    }

    // ── Pricing toggle ───────────────────────────────────────────────────────
    const toggleBtns = document.querySelectorAll('.toggle-btn');
    const allMonthlyPrices = document.querySelectorAll('.price-monthly');
    const allAnnualPrices  = document.querySelectorAll('.price-annually');

    toggleBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            toggleBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            const showMonthly = btn.dataset.billing === 'monthly';
            allMonthlyPrices.forEach(el => el.classList.toggle('hidden', !showMonthly));
            allAnnualPrices.forEach(el => el.classList.toggle('hidden',  showMonthly));
        });
    });

    // ── Scroll reveal system ─────────────────────────────────────────────────
    const THRESHOLD = 0.12;
    const ROOT_MARGIN = '0px 0px -60px 0px';

    // 1. Simple [data-reveal] elements (slide left/right/up)
    const revealEls = document.querySelectorAll('[data-reveal]');
    if (revealEls.length) {
        const revealObserver = new IntersectionObserver(entries => {
            entries.forEach(entry => {
                if (!entry.isIntersecting) return;
                const delay = parseInt(entry.target.dataset.revealDelay || '0', 10);
                setTimeout(() => entry.target.classList.add('is-visible'), delay);
                revealObserver.unobserve(entry.target);
            });
        }, { threshold: THRESHOLD, rootMargin: ROOT_MARGIN });

        revealEls.forEach(el => revealObserver.observe(el));
    }

    // 2. [data-stagger] containers — stagger children with delay
    const staggerContainers = document.querySelectorAll('[data-stagger]');
    if (staggerContainers.length) {
        const staggerObserver = new IntersectionObserver(entries => {
            entries.forEach(entry => {
                if (!entry.isIntersecting) return;
                const children = [...entry.target.children];
                children.forEach((child, i) => {
                    child.style.setProperty('--stagger-delay', `${i * 90}ms`);
                });
                entry.target.classList.add('is-visible');
                staggerObserver.unobserve(entry.target);
            });
        }, { threshold: 0.05, rootMargin: ROOT_MARGIN });

        staggerContainers.forEach(el => staggerObserver.observe(el));
    }

    // 3. Legacy .fade-in elements
    const faders = document.querySelectorAll('.fade-in');
    if (faders.length) {
        const fadeObserver = new IntersectionObserver(entries => {
            entries.forEach(entry => {
                if (!entry.isIntersecting) return;
                entry.target.classList.add('appear');
                fadeObserver.unobserve(entry.target);
            });
        }, { threshold: THRESHOLD, rootMargin: ROOT_MARGIN });

        faders.forEach(el => fadeObserver.observe(el));
    }

});
