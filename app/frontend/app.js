// État de l'application
let todos = [];
let toastInstance;

// Initialisation
document.addEventListener('DOMContentLoaded', () => {
    // Initialiser le toast Bootstrap
    const toastElement = document.getElementById('notificationToast');
    toastInstance = new bootstrap.Toast(toastElement);
    
    // Charger les tâches
    loadTodos();
    
    // Configurer le formulaire
    document.getElementById('todoForm').addEventListener('submit', (e) => {
        e.preventDefault();
        addTodo();
    });
    
    // Rafraîchir toutes les 30 secondes
    setInterval(loadTodos, 30000);
});

// Charger toutes les tâches
async function loadTodos() {
    try {
        const response = await fetch(getApiUrl('/todos'));
        
        if (!response.ok) {
            throw new Error(`Erreur HTTP: ${response.status}`);
        }
        
        todos = await response.json();
        renderTodos();
        updateStats();
    } catch (error) {
        console.error('Erreur lors du chargement des tâches:', error);
        showError('Impossible de charger les tâches. Vérifiez votre connexion.');
        
        // Afficher un message dans la liste
        const todoList = document.getElementById('todoList');
        todoList.innerHTML = `
            <div class="alert alert-danger" role="alert">
                <i class="bi bi-exclamation-triangle-fill"></i>
                <strong>Erreur de connexion</strong><br>
                Impossible de se connecter à l'API. Vérifiez que le backend est en cours d'exécution.
                <hr>
                <small>URL de l'API: ${API_CONFIG.baseURL}</small>
            </div>
        `;
    }
}

// Afficher les tâches
function renderTodos() {
    const todoList = document.getElementById('todoList');
    todoList.innerHTML = '';
    
    if (!todos || todos.length === 0) {
        todoList.innerHTML = `
            <div class="text-center text-muted py-5">
                <i class="bi bi-inbox" style="font-size: 3rem;"></i>
                <p class="mt-3">Aucune tâche pour le moment.<br>Ajoutez-en une pour commencer !</p>
            </div>
        `;
        return;
    }
    
    todos.forEach(todo => {
        const todoItem = createTodoElement(todo);
        todoList.appendChild(todoItem);
    });
}

// Créer un élément de tâche
function createTodoElement(todo) {
    const div = document.createElement('div');
    div.className = `todo-item ${todo.completed ? 'completed' : ''}`;
    
    const date = new Date(todo.created_at);
    const formattedDate = date.toLocaleDateString('fr-FR', {
        day: 'numeric',
        month: 'short',
        year: 'numeric'
    });
    
    div.innerHTML = `
        <div class="d-flex justify-content-between align-items-start">
            <div class="flex-grow-1 me-3">
                <div class="d-flex align-items-center mb-2">
                    <h6 class="mb-0 ${todo.completed ? 'text-decoration-line-through text-muted' : ''}">
                        ${escapeHtml(todo.title)}
                    </h6>
                    ${todo.completed ? '<span class="badge bg-success ms-2">Terminée</span>' : ''}
                </div>
                ${todo.description ? `
                    <p class="mb-1 small ${todo.completed ? 'text-muted' : 'text-secondary'}">
                        ${escapeHtml(todo.description)}
                    </p>
                ` : ''}
                <small class="text-muted">
                    <i class="bi bi-calendar-event"></i> ${formattedDate}
                </small>
            </div>
            <div class="btn-group-vertical" role="group">
                <button type="button" 
                        class="btn btn-sm ${todo.completed ? 'btn-outline-warning' : 'btn-outline-success'}" 
                        onclick="toggleTodo(${todo.id}, ${!todo.completed})"
                        title="${todo.completed ? 'Marquer comme non terminée' : 'Marquer comme terminée'}">
                    <i class="bi ${todo.completed ? 'bi-arrow-counterclockwise' : 'bi-check-lg'}"></i>
                </button>
                <button type="button" 
                        class="btn btn-sm btn-outline-danger" 
                        onclick="deleteTodo(${todo.id})"
                        title="Supprimer">
                    <i class="bi bi-trash"></i>
                </button>
            </div>
        </div>
    `;
    
    return div;
}

// Ajouter une tâche
async function addTodo() {
    const title = document.getElementById('todoTitle').value.trim();
    const description = document.getElementById('todoDescription').value.trim();
    
    if (!title) {
        showError('Le titre est requis');
        return;
    }
    
    try {
        const response = await fetch(getApiUrl('/todos'), {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                title: title,
                description: description,
                completed: false
            })
        });
        
        if (!response.ok) {
            throw new Error(`Erreur HTTP: ${response.status}`);
        }
        
        // Réinitialiser le formulaire
        document.getElementById('todoForm').reset();
        
        // Recharger les tâches
        await loadTodos();
        
        showSuccess('Tâche ajoutée avec succès');
    } catch (error) {
        console.error('Erreur lors de l\'ajout:', error);
        showError('Impossible d\'ajouter la tâche');
    }
}

// Basculer l'état d'une tâche
async function toggleTodo(id, completed) {
    const todo = todos.find(t => t.id === id);
    if (!todo) return;
    
    try {
        const response = await fetch(getApiUrl(`/todos/${id}`), {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                title: todo.title,
                description: todo.description,
                completed: completed
            })
        });
        
        if (!response.ok) {
            throw new Error(`Erreur HTTP: ${response.status}`);
        }
        
        await loadTodos();
        showSuccess(completed ? 'Tâche marquée comme terminée' : 'Tâche marquée comme non terminée');
    } catch (error) {
        console.error('Erreur lors de la mise à jour:', error);
        showError('Impossible de mettre à jour la tâche');
    }
}

// Supprimer une tâche
async function deleteTodo(id) {
    if (!confirm('Êtes-vous sûr de vouloir supprimer cette tâche ?')) {
        return;
    }
    
    try {
        const response = await fetch(getApiUrl(`/todos/${id}`), {
            method: 'DELETE'
        });
        
        if (!response.ok) {
            throw new Error(`Erreur HTTP: ${response.status}`);
        }
        
        await loadTodos();
        showSuccess('Tâche supprimée');
    } catch (error) {
        console.error('Erreur lors de la suppression:', error);
        showError('Impossible de supprimer la tâche');
    }
}

// Mettre à jour les statistiques
function updateStats() {
    const total = todos.length;
    const completed = todos.filter(t => t.completed).length;
    const pending = total - completed;
    
    document.getElementById('totalTasks').textContent = total;
    document.getElementById('completedTasks').textContent = completed;
    document.getElementById('pendingTasks').textContent = pending;
}

// Fonctions utilitaires
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function showSuccess(message) {
    showToast(message, 'success');
}

function showError(message) {
    showToast(message, 'danger');
}

function showToast(message, type) {
    const toast = document.getElementById('notificationToast');
    const toastBody = document.getElementById('toastMessage');
    
    // Définir le type (success ou danger)
    toast.classList.remove('bg-success', 'bg-danger');
    toast.classList.add(`bg-${type}`, 'text-white');
    
    // Définir le message
    toastBody.textContent = message;
    
    // Afficher le toast
    toastInstance.show();
}