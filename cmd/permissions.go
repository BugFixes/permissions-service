package main

import (
	"fmt"
	"net/http"
	"os"
	"time"

	bugLog "github.com/bugfixes/go-bugfixes/logs"
	bugfixes "github.com/bugfixes/go-bugfixes/middleware"
	"github.com/bugfixes/permissions/internal/config"
	"github.com/bugfixes/permissions/internal/permissions"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/keloran/go-probe"
)

func main() {
	bugLog.Local().Info("starting permissions")

	cfg, err := config.Build()
	if err != nil {
		bugLog.Info(err)
		return
	}

	if err := route(&cfg); err != nil {
		bugLog.Info(err)
		return
	}
}

func route(cfg *config.Config) error {
	r := chi.NewRouter()
	r.Use(middleware.Timeout(60 * time.Second))
	r.Use(middleware.RequestID)
	r.Use(middleware.Heartbeat("/ping"))
	r.Use(bugfixes.BugFixes)

	permissionsPrefix := ""
	if os.Getenv("DEVELOPMENT") == "true" {
		permissionsPrefix = "permissions"
	}

	r.Route(fmt.Sprintf("/%s/login", permissionsPrefix), func(r chi.Router) {
		r.Post("/", permissions.Login)
	})

	r.Route(fmt.Sprintf("/%s", permissionsPrefix), func(r chi.Router) {
		r.Get("/", permissions.CheckPermissions)
		r.Post("/", permissions.CreatePermission)
		r.Put("/", permissions.UpdatePermission)
		r.Delete("/", permissions.DeletePermission)
	})

	r.Route("/probe", func(r chi.Router) {
		r.Get("/", probe.HTTP)
	})

	bugLog.Local().Infof("listening on port: %d\n", cfg.Local.Port)
	if err := http.ListenAndServe(fmt.Sprintf(":%d", cfg.Local.Port), r); err != nil {
		return bugLog.Errorf("port failed: %+v", err)
	}

	return nil
}
