# Azure Deployment Instruction

This guide helps ParkPie team members redeploy the **Spring Boot backend** to Azure App Service.

---

## 📌 When Do I Need to Redeploy?

Redeploy the backend if:

- You updated any code in `apps/backend/` (e.g., controllers, services, entities)
- You changed dependencies in `build.gradle`
- You changed the JAR file name or backend configuration
- You fixed bugs or added new features to the backend

If you only changed Flutter frontend code, **no backend redeployment is needed**.

---

##  Pre-requisites

Make sure the following tools and environment are set up **before deploying**:

_Please register an account, and I will authorize first._
1. ✅ [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed
2. ✅ Logged in to Azure:
   ```bash
   az login
   ```

## Step 1: Build the Backend

From the project root:

```bash
cd apps/backend
./gradlew clean bootJar
ls -lh build/libs
```
or, an easier way, use your intelliJ IDEA - click "Gradle" on the right side of the window - double click "bootJar" under build folder.

Check that the file looks like backend-0.0.1-SNAPSHOT.jar exists.

## Step 2: Deploy to Azure

Confirm the account exists:

```bash
az account show
```
Confirm the group resource exists:

```bash
az group show -n parkpie-rg
```
Deploy (make sure the jar file name is correct):

```bash
az webapp deploy \
  --resource-group parkpie-rg \
  --name parkpie-backend \
  --src-path build/libs/backend-0.0.1-SNAPSHOT.jar \
  --type jar
```
Expected response:
```json
{
   "id": "/subscriptions/a7978973-2830-4e7c-b6b9-d8dd714a5d2f/resourceGroups/parkpie-rg/providers/Microsoft.Web/sites/parkpie-90018/deploymentStatus/b5c290d7-550d-4273-8e06-f609fdc1afb9",
   "location": "Australia East",
   "name": "b5c290d7-550d-4273-8e06-f609fdc1afb9",
   "properties": {
      "deploymentId": "b5c290d7-550d-4273-8e06-f609fdc1afb9",
      "errors": null,
      "failedInstancesLogs": null,
      "numberOfInstancesFailed": 0,
      "numberOfInstancesInProgress": 0,
      "numberOfInstancesSuccessful": 1,
      "status": "RuntimeSuccessful"
   },
   "resourceGroup": "parkpie-rg",
   "tags": {
      "hidden-link: /app-insights-resource-id": "/subscriptions/a7978973-2830-4e7c-b6b9-d8dd714a5d2f/resourceGroups/parkpie-rg/providers/microsoft.insights/components/parkpie-90018"
   },
   "type": "Microsoft.Web/sites/deploymentStatus"
}
```
Note: if you deploy successfully, you can see a line looks like “You can visit your app at: http://parkpie-backend-hqdhhgfgfnaca4gh.australiaeast-01.azurewebsites.net” from the message, use this link plus “/health” to check the health status

## Step 3: Restart and Verify

Confirm the account exists:

```bash
az webapp restart \
  --resource-group parkpie-rg \
  --name parkpie-backend
```
You can check the log through:

```bash
az webapp log tail \
  --resource-group parkpie-rg \
  --name parkpie-90018

```

Status Checking:
https://parkpie-90018.azurewebsites.net/actuator/health
https://parkpie-90018.azurewebsites.net/actuator/health/db
https://parkpie-90018.azurewebsites.net/health
https://parkpie-90018.azurewebsites.net/admin/login

_Notes:_

_The backend is always running on Azure (24/7)._

_No need to restart it manually unless you change the code._


