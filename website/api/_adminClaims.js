function claimsForAdminRole(currentClaims = {}, role = 'user') {
    const nextClaims = {
        ...currentClaims,
        luumAdmin: role === 'admin'
    };

    if (role !== 'admin' && nextClaims.admin === true) {
        nextClaims.admin = false;
    }

    return nextClaims;
}

module.exports = { claimsForAdminRole };
