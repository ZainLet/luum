function badJSON(message) {
    const error = new Error(message);
    error.statusCode = 400;
    return error;
}

function jsonBody(req, message = 'JSON inválido') {
    if (!req.body) return {};
    if (typeof req.body === 'string') {
        try {
            return JSON.parse(req.body || '{}');
        } catch {
            throw badJSON(message);
        }
    }
    return req.body;
}

async function parseJsonBody(req, message) {
    return jsonBody(req, message);
}

module.exports = {
    jsonBody,
    parseJsonBody
};
