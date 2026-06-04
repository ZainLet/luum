function profileEmail(decodedToken) {
    const email = String(decodedToken?.email || '').trim().toLowerCase();
    return email || null;
}

function profileText(primary, fallback, maxLength = 200) {
    const text = String(primary || fallback || '').trim();
    return text ? text.slice(0, maxLength) : null;
}

function profileList(value, maxItems = 12, maxLength = 80) {
    if (!Array.isArray(value)) return [];
    return [...new Set(value
        .map((item) => profileText(item, '', maxLength))
        .filter(Boolean))]
        .slice(0, maxItems);
}

function profileOnboarding(value) {
    if (!value || typeof value !== 'object') return null;

    const onboarding = {
        cargo: profileText(value.cargo, '', 120),
        time: profileText(value.time, '', 80),
        ferramentas: profileList(value.ferramentas || value.tools),
        objetivo: profileText(value.objetivo, '', 160)
    };

    return Object.values(onboarding).some((item) => Array.isArray(item) ? item.length : Boolean(item))
        ? onboarding
        : null;
}

module.exports = {
    profileEmail,
    profileOnboarding,
    profileText
};
