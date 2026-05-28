package com.parafix.app

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

class StorageHelper(context: Context) {
    private val prefs = context.getSharedPreferences("parafix_prefs", Context.MODE_PRIVATE)
    private val gson = Gson()

    fun saveExpenses(expenses: List<ExpenseEntry>) {
        val json = gson.toJson(expenses)
        prefs.edit().putString("expenses_list", json).apply()
    }

    fun getExpenses(): List<ExpenseEntry> {
        val json = prefs.getString("expenses_list", null) ?: return emptyList()
        return try {
            val type = object : TypeToken<List<ExpenseEntry>>() {}.type
            gson.fromJson(json, type)
        } catch (e: Exception) {
            emptyList()
        }
    }
}
