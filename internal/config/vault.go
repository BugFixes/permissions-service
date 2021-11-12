package config

import (
	"net/http"
	"os"
	"time"

	bugLog "github.com/bugfixes/go-bugfixes/logs"
	"github.com/hashicorp/vault/api"
)

func GetVaultSecrets(vaultAddress, secretPath string) (map[string]interface{}, error) {
	httpClient := &http.Client{
		Timeout: 10 * time.Second,
	}

	var m = make(map[string]interface{})

	token := os.Getenv("VAULT_TOKEN")
	if token == "" {
		return m, bugLog.Error("token not found")
	}

	client, err := api.NewClient(&api.Config{
		Address:    vaultAddress,
		HttpClient: httpClient,
	})
	if err != nil {
		return m, bugLog.Errorf("client: %+v", err)
	}
	client.SetToken(token)

	data, err := client.Logical().Read(secretPath)
	if err != nil {
		return m, bugLog.Errorf("read: %+v", err)
	}

	return data.Data, nil
}
