package com.parafix.app

import java.util.UUID

enum class ExpenseCategory(val displayName: String, val colorHex: String) {
    FOOD("Food & Drinks", "#FF6B6B"),
    TRANSPORT("Transport", "#4DABF7"),
    ENTERTAINMENT("Entertainment", "#CC5DE8"),
    BILLS("Bills & Utilities", "#FFD43B"),
    OTHER("Other", "#868E96")
}

data class ExpenseEntry(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val amount: Double,
    val dateEpoch: Long = System.currentTimeMillis(),
    val category: ExpenseCategory
)
