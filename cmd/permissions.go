package main

import (
  bugLog "github.com/bugfixes/go-bugfixes/logs"
  "github.com/bugfixes/permissions/internal/config"
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
  return nil
}
