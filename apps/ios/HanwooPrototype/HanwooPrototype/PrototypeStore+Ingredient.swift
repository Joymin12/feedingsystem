import SwiftUI

// MARK: - PrototypeStore 원료 책임
// 원료 정의 조회, 사용자 원료(USER_...) CRUD 및 영속화.

extension PrototypeStore {
    func ingredientDefinition(id: String) -> IngredientDefinition? {
        ingredientDefinitions.first(where: { $0.id == id }) ??
            userIngredientDefinitions.first(where: { $0.id == id })?.ingredientDefinition
    }

    func definitions(for category: IngredientCategory) -> [IngredientDefinition] {
        let catalog = ingredientDefinitions.filter { $0.category == category }
        let userDefinitions = visibleUserIngredientDefinitions()
            .map(\.ingredientDefinition)
            .filter { $0.category == category }
        return catalog + userDefinitions
    }

    func availableDefinitions(for category: IngredientCategory) -> [IngredientDefinition] {
        let catalog = ingredientDefinitions.filter { $0.category == category }
        let userDefinitions = visibleUserIngredientDefinitions()
            .map(\.ingredientDefinition)
            .filter { $0.category == category }
        guard let currentUser, !currentUser.selectedIngredientIDs.isEmpty else {
            return catalog + userDefinitions
        }
        return catalog.filter { currentUser.selectedIngredientIDs.contains($0.id) } + userDefinitions
    }

    func addUserIngredient(
        to formulaID: UUID,
        name: String,
        category: IngredientCategory,
        amount: Double,
        defaultPriceKrwPerKg: Int,
        nutrition: IngredientNutritionProfile
    ) {
        guard let index = formulas.firstIndex(where: { $0.id == formulaID }) else { return }
        let customDefinition = UserIngredientDefinition(
            ownerLoginID: currentLoginID,
            name: name,
            category: category,
            defaultPriceKrwPerKg: defaultPriceKrwPerKg,
            nutrition: nutrition
        )
        userIngredientDefinitions.append(customDefinition)
        saveUserIngredients()
        formulas[index].items.append(IngredientLine(
            name: customDefinition.name,
            definitionID: customDefinition.id,
            amount: amount,
            unit: .kg
        ))
    }

    func myUserIngredientDefinitions() -> [UserIngredientDefinition] {
        visibleUserIngredientDefinitions().sorted {
            if $0.category.rawValue == $1.category.rawValue {
                return $0.name < $1.name
            }
            return $0.category.rawValue < $1.category.rawValue
        }
    }

    func updateUserIngredient(_ ingredient: UserIngredientDefinition) {
        guard let index = userIngredientDefinitions.firstIndex(where: { $0.id == ingredient.id }) else { return }
        guard userIngredientDefinitions[index].ownerLoginID == currentLoginID ||
                userIngredientDefinitions[index].ownerLoginID == nil else { return }
        userIngredientDefinitions[index] = ingredient
        saveUserIngredients()

        for formulaIndex in formulas.indices {
            for itemIndex in formulas[formulaIndex].items.indices {
                if formulas[formulaIndex].items[itemIndex].definitionID == ingredient.id {
                    formulas[formulaIndex].items[itemIndex].name = ingredient.name
                }
            }
        }
    }

    func deleteUserIngredient(id: String) {
        guard let ingredient = userIngredientDefinitions.first(where: { $0.id == id }) else { return }
        guard ingredient.ownerLoginID == currentLoginID || ingredient.ownerLoginID == nil else { return }
        userIngredientDefinitions.removeAll(where: { $0.id == id })
        saveUserIngredients()

        for formulaIndex in formulas.indices {
            formulas[formulaIndex].items.removeAll(where: { $0.definitionID == id })
        }
    }

    func formulaUsageCount(forUserIngredientID id: String) -> Int {
        formulas.reduce(0) { count, formula in
            count + formula.items.filter { $0.definitionID == id }.count
        }
    }

    private func saveUserIngredients() {
        userIngredientRepository.saveUserIngredients(userIngredientDefinitions)
    }

    private func visibleUserIngredientDefinitions() -> [UserIngredientDefinition] {
        guard let currentLoginID else { return userIngredientDefinitions }
        return userIngredientDefinitions.filter { $0.ownerLoginID == nil || $0.ownerLoginID == currentLoginID }
    }
}
