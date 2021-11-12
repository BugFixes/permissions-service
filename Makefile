SERVICE_NAME=agent
STACK_TIME=$(shell date "+%y-%m-%d_%H-%M")
-include .env
export

.PHONY: setup
setup: ## Get linting stuffs
	go get github.com/golangci/golangci-lint/cmd/golangci-lint
	go get golang.org/x/tools/cmd/goimports

.PHONY: build-images
build-images: ## Build the images
	docker buildx build --platform linux/arm64 --tag "ghcr.io/bugfixes/agent-service:`git rev-parse HEAD`" --build-arg build=`git rev-parse HEAD` --build-arg version=`git describe --tags --dirty` --file ./k8s/Dockerfile .
	docker tag "ghcr.io/bugfixes/agent-service:`git rev-parse HEAD`" "ghcr.io/bugfixes/agent-service:latest"
	docker scan "ghcr.io/bugfixes/agent-service:`git rev-parse HEAD`"

.PHONY: build
build: lint build-images ## Build the app

.PHONY: test
test: lint ## Test the app
	go test -v -race -bench=./... -benchmem -timeout=120s -cover -coverprofile=./test/coverage.txt -bench=./... ./...

.PHONY: run
run: build ## Build and run
	bin/${SERVICE_NAME}

.PHONY: lambda
lambda: ## Run the lambda version
	go build ./cmd/main

.PHONY: mocks
mocks: ## Generate the mocks
	go generate ./...

.PHONY: full
full: clean build fmt lint test ## Clean, build, make sure its formatted, linted, and test it

.PHONY: docker-up
docker-up: docker-start sleepy ## Start docker

docker-start: ## Docker Start
	docker compose -p ${SERVICE_NAME} --project-directory=docker up -d

docker-stop: ## Docker Stop
	docker compose -p ${SERVICE_NAME} --project-directory=docker down

.PHONY: docker-down
docker-down: docker-stop ## Stop docker

.PHONY: docker-restart
docker-restart: docker-down docker-up ## Restart Docker

.PHONY: docker-logs
docker-logs: ## Follow the logs
	docker logs -f ${SERVICE_NAME}_localstack_1

.PHONY: lint
lint: ## Lint
	golangci-lint run --config configs/golangci.yml

.PHONY: fmt
fmt: ## Formatting
	gofmt -w -s .
	goimports -w .
	go clean ./...

.PHONY: pre-commit
pre-commit: fmt lint ## Do formatting and linting

.PHONY: clean
clean: ## Clean
	go clean ./...
	rm -rf bin/${SERVICE_NAME}

sleepy: ## Sleepy
	sleep 60

.PHONY: cloud-up
cloud-up: docker-start sleepy stack-create ## CloudFormation Up

.PHONY: cloud-restart
cloud-restart: docker-down cloud-up

.PHONY: stack-create
stack-create: # Create the stack
	aws cloudformation create-stack \
  		--template-body file://docker/cloudformation.yaml \
  		--stack-name ${SERVICE_NAME}-$(STACK_TIME) \
  		--endpoint https://localhost.localstack.cloud:4566 \
  		--region us-east-1 \
  		--parameters \
  		  ParameterKey=GithubKey,ParameterValue=${GITHUB_CLIENT_ID} \
  		  ParameterKey=GithubSecret,ParameterValue=${GITHUB_CLIENT_SECRET} \
  		  ParameterKey=GithubAppId,ParameterValue=${GITHUB_APP_ID} \
  		  ParameterKey=GoogleKey,ParameterValue=${GOOGLE_CLIENT_ID} \
  		  ParameterKey=GoogleSecret,ParameterValue=${GOOGLE_CLIENT_SECRET} \
  		  ParameterKey=JWTSecret,ParameterValue=${JWT_SECRET} \
  		  ParameterKey=DiscordAppId,ParameterValue=${DISCORD_APP_ID} \
  		  ParameterKey=DiscordPublicKey,ParameterValue=${DISCORD_PUBLIC_KEY} \
  		  ParameterKey=DiscordClientID,ParameterValue=${DISCORD_CLIENT_ID} \
  		  ParameterKey=DiscordClientSecret,ParameterValue=${DISCORD_CLIENT_SECRET} \
  		  ParameterKey=DiscordBotToken,ParameterValue=${DISCORD_BOT_TOKEN} \
  		1> /dev/null

.PHONY: stack-delete
stack-delete: # Delete the stack
	aws cloudformation delete-stack \
		--stack-name ${SERVICE_NAME}-$(STACK_TIME) \
		--endpoint http://localhost.localstack.cloud:4566 \
		--region us-east-1

.PHONY: wipeData
wipeData: # Wipe Data
	cat ./docker/drop.sql | docker exec -i agent_database_1 psql -U database_username -d bugfixes

.PHONY: injectData
injectData: # Wipe Data
	cat ./docker/create.sql | docker exec -i agent_database_1 psql -U database_username -d bugfixes
	cat ./docker/local.sql | docker exec -i agent_database_1 psql -U database_username -d bugfixes

.PHONY: reset-tables
reset-tables: wipeData injectData # Reset the tables

.PHONY: bucket-up
bucket-up: bucket-create bucket-upload ## S3 Bucket Up

bucket-create: ## Create the bucket for builds
	aws s3api create-bucket \
		--endpoint https://localhost.localstack.cloud:4566 \
		--bucket celeste \
		--quiet

bucket-upload: build-aws ## Put the build in the bucket
	aws s3 cp bin/celeste-local.zip s3://agent/agent-local.zip --endpoint https://localhost.localstack.cloud:4566

build-aws: ## Build for AWS
	GOOS=linux GOARCH=amd64 go build -o bin/agent ./cmd
	zip bin/agent-local.zip bin/agent
