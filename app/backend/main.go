package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
)

type Todo struct {
	ID          int       `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Completed   bool      `json:"completed"`
	CreatedAt   time.Time `json:"created_at"`
}

type DBCredentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Host     string `json:"host"`
	Port     int    `json:"port"`
	DBName   string `json:"dbname"`
}

var db *sql.DB

func main() {
	log.Println("Démarrage de l'application DevOps Todo API...")

	// Connexion à la base de données
	var err error
	db, err = connectToDB()
	if err != nil {
		log.Fatal("Échec de la connexion à la base de données:", err)
	}
	defer db.Close()

	log.Println("✓ Connecté à la base de données PostgreSQL")

	// Créer la table si elle n'existe pas
	if err := createTable(); err != nil {
		log.Fatal("Échec de la création de la table:", err)
	}
	log.Println("✓ Table 'todos' prête")

	// Configuration du routeur
	router := mux.NewRouter()

	// Routes API
	router.HandleFunc("/api/health", healthCheck).Methods("GET")
	router.HandleFunc("/api/todos", getTodos).Methods("GET")
	router.HandleFunc("/api/todos", createTodo).Methods("POST")
	router.HandleFunc("/api/todos/{id}", getTodo).Methods("GET")
	router.HandleFunc("/api/todos/{id}", updateTodo).Methods("PUT")
	router.HandleFunc("/api/todos/{id}", deleteTodo).Methods("DELETE")

	// CORS Middleware
	router.Use(corsMiddleware)
	router.Use(loggingMiddleware)

	// Démarrer le serveur
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("✓ Serveur démarré sur le port %s", port)
	log.Printf("✓ API disponible sur http://localhost:%s/api", port)
	
	if err := http.ListenAndServe(":"+port, router); err != nil {
		log.Fatal(err)
	}
}

func connectToDB() (*sql.DB, error) {
	// Lire les credentials depuis le fichier JSON
	credsFile := os.Getenv("DB_CREDENTIALS_FILE")
	if credsFile == "" {
		credsFile = "/app/db-credentials.json"
	}

	data, err := os.ReadFile(credsFile)
	if err != nil {
		return nil, fmt.Errorf("échec de lecture du fichier credentials: %v", err)
	}

	var creds DBCredentials
	if err := json.Unmarshal(data, &creds); err != nil {
		return nil, fmt.Errorf("échec du parsing des credentials: %v", err)
	}

	// Connection string
	connStr := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=require",
		creds.Host, creds.Port, creds.Username, creds.Password, creds.DBName)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, err
	}

	// Configuration du pool de connexions
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	// Test de la connexion
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("impossible de se connecter à la base: %v", err)
	}

	return db, nil
}

func createTable() error {
	query := `
	CREATE TABLE IF NOT EXISTS todos (
		id SERIAL PRIMARY KEY,
		title VARCHAR(255) NOT NULL,
		description TEXT,
		completed BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	)`

	_, err := db.Exec(query)
	return err
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		// Créer un ResponseWriter qui capture le status code
		lw := &loggingResponseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		
		next.ServeHTTP(lw, r)
		
		duration := time.Since(start)
		log.Printf("%s %s %d %v", r.Method, r.URL.Path, lw.statusCode, duration)
	})
}

type loggingResponseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (lw *loggingResponseWriter) WriteHeader(code int) {
	lw.statusCode = code
	lw.ResponseWriter.WriteHeader(code)
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	// Vérifier la connexion à la base de données
	if err := db.Ping(); err != nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{
			"status":  "unhealthy",
			"message": "Database connection failed",
		})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":    "healthy",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

func getTodos(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, title, description, completed, created_at FROM todos ORDER BY created_at DESC")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	todos := []Todo{}
	for rows.Next() {
		var todo Todo
		if err := rows.Scan(&todo.ID, &todo.Title, &todo.Description, &todo.Completed, &todo.CreatedAt); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		todos = append(todos, todo)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(todos)
}

func getTodo(w http.ResponseWriter, r *http.Request) {
	params := mux.Vars(r)
	id, err := strconv.Atoi(params["id"])
	if err != nil {
		http.Error(w, "ID invalide", http.StatusBadRequest)
		return
	}

	var todo Todo
	err = db.QueryRow("SELECT id, title, description, completed, created_at FROM todos WHERE id = $1", id).
		Scan(&todo.ID, &todo.Title, &todo.Description, &todo.Completed, &todo.CreatedAt)

	if err == sql.ErrNoRows {
		http.Error(w, "Tâche non trouvée", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(todo)
}

func createTodo(w http.ResponseWriter, r *http.Request) {
	var todo Todo
	if err := json.NewDecoder(r.Body).Decode(&todo); err != nil {
		http.Error(w, "Données invalides: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Validation
	if todo.Title == "" {
		http.Error(w, "Le titre est requis", http.StatusBadRequest)
		return
	}

	err := db.QueryRow(
		"INSERT INTO todos (title, description, completed) VALUES ($1, $2, $3) RETURNING id, created_at",
		todo.Title, todo.Description, todo.Completed,
	).Scan(&todo.ID, &todo.CreatedAt)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(todo)
}

func updateTodo(w http.ResponseWriter, r *http.Request) {
	params := mux.Vars(r)
	id, err := strconv.Atoi(params["id"])
	if err != nil {
		http.Error(w, "ID invalide", http.StatusBadRequest)
		return
	}

	var todo Todo
	if err := json.NewDecoder(r.Body).Decode(&todo); err != nil {
		http.Error(w, "Données invalides: "+err.Error(), http.StatusBadRequest)
		return
	}

	result, err := db.Exec(
		"UPDATE todos SET title = $1, description = $2, completed = $3 WHERE id = $4",
		todo.Title, todo.Description, todo.Completed, id,
	)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		http.Error(w, "Tâche non trouvée", http.StatusNotFound)
		return
	}

	todo.ID = id
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(todo)
}

func deleteTodo(w http.ResponseWriter, r *http.Request) {
	params := mux.Vars(r)
	id, err := strconv.Atoi(params["id"])
	if err != nil {
		http.Error(w, "ID invalide", http.StatusBadRequest)
		return
	}

	result, err := db.Exec("DELETE FROM todos WHERE id = $1", id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		http.Error(w, "Tâche non trouvée", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}