package config

import (
	"os"

	bugLog "github.com/bugfixes/go-bugfixes/logs"
)

type RDS struct {
	Username string
	Password string
	Hostname string
	Port     string
	Database string
}

func buildDatabase(c *Config) error {
	if getDatabaseEnvs(c) {
		return nil
	}

	val, err := GetVaultSecrets(c.Local.VaultAddress, "database/creds/agent-role")
	if err != nil {
		return bugLog.Errorf("vaultSecrets: %+v", err)
	}

	c.RDS = RDS{
		Hostname: c.Local.RDSAddress,
		Database: "postgres",
		Username: val["username"].(string),
		Password: val["password"].(string),
	}

	return nil
}

func getDatabaseEnvs(c *Config) bool {
	rds := RDS{
		Database: "postgres",
	}
	if username := os.Getenv("RDS_USERNAME"); username != "" {
		rds.Username = username
	}

	if password := os.Getenv("RDS_PASSWORD"); password != "" {
		rds.Password = password
	}

	if hostname := os.Getenv("RDS_HOSTNAME"); hostname != "" {
		rds.Hostname = hostname
	}

	if rds.Hostname != "" && rds.Username != "" && rds.Password != "" {
		c.RDS = rds
		return true
	}

	return false
}
