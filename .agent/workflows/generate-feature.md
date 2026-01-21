---
description: Automated feature generation to create Model, Service, and Provider boilerplate rapidly.
---

# Feature Generator Workflow

Using this workflow, you can generate the complete boilerplate for a new feature (Model, Service, Provider) in seconds.

## Steps to Execute

1.  **Analyze Request**: Identify the `FeatureName` (e.g., "Course", "User", "Order") and the fields purely from the User's prompt to avoid guessing.
2.  **Create Model**:
    *   Path: `lib/models/[feature_name]_model.dart`
    *   Action: Create a Data Class with `fromJson`, `toJson`, and necessary fields.
3.  **Create Service**:
    *   Path: `lib/services/[feature_name]_service.dart`
    *   Action: Create a class `[FeatureName]Service` with placeholder CRUD methods (get, add, update, delete) linked to Firebase/API.
4.  **Create Provider**:
    *   Path: `lib/providers/[feature_name]_provider.dart`
    *   Action: Create `[FeatureName]Provider` extending `ChangeNotifier`. Add `_items` list, loading state, and methods that call the Service.
5.  **Register Provider**:
    *   **Turbo Action**: Read `main.dart`, find `MultiProvider`, and add the new `ChangeNotifierProvider`.

## Example Usage
> User: "Bhai Banner ka feature banao jisme image, title aur link ho."
> Agent: Runs `generate-feature` -> Creates `BannerModel`, `BannerService`, `BannerProvider` & links in `main.dart`.
