/*
Copyright 2026 Kubermatic GmbH.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// Command hello-world serves the web page behind the Margo specification's example application
// "Hello World": the greeting that the deployment configured, and where the workload runs.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"html/template"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

// version is set at build time with -ldflags "-X main.version=...".
var version = "dev"

type info struct {
	Greeting  string `json:"greeting"`
	Addressee string `json:"addressee"`
	Node      string `json:"node"`
	Pod       string `json:"pod"`
	Namespace string `json:"namespace"`
	Version   string `json:"version"`
}

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	host, _ := os.Hostname()
	in := info{
		Greeting:  env("APP_GREETING", "Hello"),
		Addressee: env("APP_GREETING_ADDRESSEE", "World"),
		Node:      env("NODE_NAME", "unknown"),
		Pod:       env("POD_NAME", host),
		Namespace: env("POD_NAMESPACE", "unknown"),
		Version:   version,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		if err := page.Execute(w, in); err != nil {
			log.Printf("render page: %v", err)
		}
	})
	mux.HandleFunc("GET /api/info", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(in)
	})
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok\n"))
	})

	srv := &http.Server{
		Addr:              env("LISTEN_ADDRESS", ":8080"),
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutdown)
	}()

	log.Printf("hello-world %s listening on %s: %q, %q", version, srv.Addr, in.Greeting, in.Addressee)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

// page uses the Kubermatic colours: Aegean for headings, Teal 25% for the details panel.
var page = template.Must(template.New("page").Parse(`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{.Greeting}}, {{.Addressee}}!</title>
<style>
  body { margin: 0; font-family: Arial, Helvetica, sans-serif; color: #1D1D1B; background: #FFFFFF; }
  header { padding: 16px 24px; border-bottom: 2px solid #00517D; color: #00517D; font-size: 14px; }
  main { max-width: 760px; margin: 0 auto; padding: 48px 24px; }
  h1 { color: #00517D; font-size: clamp(40px, 9vw, 88px); margin: 0 0 32px; overflow-wrap: anywhere; }
  .where { background: #BFF6F4; border: 1px solid #00D9D2; border-radius: 10px; padding: 16px 20px; }
  .where dt { color: #4D4D4D; font-size: 13px; margin-top: 8px; }
  .where dd { margin: 2px 0 0; font-family: Menlo, Consolas, monospace; font-size: 16px; color: #001128; }
  footer { margin-top: 32px; color: #4D4D4D; font-size: 13px; }
</style>
</head>
<body>
<header>Margo example application &middot; Hello World</header>
<main>
  <h1>{{.Greeting}}, {{.Addressee}}!</h1>
  <dl class="where">
    <dt>Node</dt><dd>{{.Node}}</dd>
    <dt>Pod</dt><dd>{{.Pod}}</dd>
    <dt>Namespace</dt><dd>{{.Namespace}}</dd>
  </dl>
  <footer>Application <code>com-northstartida-hello-world</code>, image version {{.Version}}.
  The greeting comes from the deployment's parameters <code>greeting</code> and <code>greetingAddressee</code>.</footer>
</main>
</body>
</html>
`))
