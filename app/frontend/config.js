// Configuration de l'API
// IMPORTANT: Remplacer cette URL par l'URL de votre ALB
const API_CONFIG = {
    baseURL: 'http://YOUR_ALB_DNS_HERE/api',  // À remplacer
    timeout: 10000,
    retryAttempts: 3
};

// Fonction pour obtenir l'URL complète de l'API
function getApiUrl(endpoint) {
    return `${API_CONFIG.baseURL}${endpoint}`;
}