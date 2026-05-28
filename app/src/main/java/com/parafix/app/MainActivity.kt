package com.parafix.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : ComponentActivity() {
    private lateinit var storage: StorageHelper

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        storage = StorageHelper(this)
        setContent {
            ParafixTheme {
                MainScreen(storage)
            }
        }
    }
}

@Composable
fun ParafixTheme(content: @Composable () -> Unit) {
    val darkColors = darkColorScheme(
        primary = Color(0xFF4DABF7),
        background = Color(0xFF121212),
        surface = Color(0xFF1E1E1E),
        onPrimary = Color.White,
        onBackground = Color(0xFFECEFF1),
        onSurface = Color.White
    )
    MaterialTheme(
        colorScheme = darkColors,
        content = content
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(storage: StorageHelper) {
    var expenses by remember { mutableStateOf(storage.getExpenses()) }
    var showDialog by remember { mutableStateOf(false) }

    val totalAmount = expenses.sumOf { it.amount }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        "Parafix",
                        fontWeight = FontWeight.Bold,
                        fontSize = 24.sp,
                        color = Color(0xFF4DABF7)
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF121212)
                )
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showDialog = true },
                containerColor = Color(0xFF4DABF7),
                contentColor = Color.White
            ) {
                Icon(Icons.Default.Add, contentDescription = "Add Expense")
            }
        },
        containerColor = Color(0xFF121212)
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
        ) {
            TotalBalanceCard(totalAmount)
            
            Spacer(modifier = Modifier.height(24.dp))
            
            CategoryDistribution(expenses)
            
            Spacer(modifier = Modifier.height(24.dp))
            
            Text(
                "Recent Expenses",
                fontWeight = FontWeight.SemiBold,
                fontSize = 18.sp,
                color = Color.Gray,
                modifier = Modifier.padding(bottom = 8.dp)
            )
            
            ExpenseList(expenses, onDelete = { target ->
                expenses = expenses.filter { it.id != target.id }
                storage.saveExpenses(expenses)
            })
        }
    }

    if (showDialog) {
        AddExpenseDialog(
            onDismiss = { showDialog = false },
            onSave = { title, amount, category ->
                val newExpense = ExpenseEntry(
                    title = title,
                    amount = amount,
                    category = category
                )
                expenses = expenses + newExpense
                storage.saveExpenses(expenses)
                showDialog = false
            }
        )
    }
}

@Composable
fun TotalBalanceCard(total: Double) {
    val gradient = Brush.linearGradient(
        colors = listOf(Color(0xFF228BE6), Color(0xFF15AABF))
    )
    Card(
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier
            .fillMaxWidth()
            .height(130.dp),
        elevation = CardDefaults.cardElevation(8.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(gradient)
                .padding(24.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            Column {
                Text(
                    "TOTAL SPENT",
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.8f),
                    fontWeight = FontWeight.Medium
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    "$${String.format(Locale.US, "%.2f", total)}",
                    fontSize = 32.sp,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
fun CategoryDistribution(expenses: List<ExpenseEntry>) {
    val categoryTotals = expenses.groupBy { it.category }
        .mapValues { entry -> entry.value.sumOf { it.amount } }

    val maxTotal = categoryTotals.values.maxOrNull() ?: 1.0

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                "Category Spending",
                fontWeight = FontWeight.SemiBold,
                fontSize = 16.sp,
                color = Color.White
            )
            Spacer(modifier = Modifier.height(16.dp))
            ExpenseCategory.values().forEach { category ->
                val amount = categoryTotals[category] ?: 0.0
                val progress = (amount / maxTotal).toFloat()
                
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                ) {
                    Text(
                        category.displayName,
                        fontSize = 12.sp,
                        color = Color.Gray,
                        modifier = Modifier.width(100.dp)
                    )
                    LinearProgressIndicator(
                        progress = { progress },
                        color = Color(android.graphics.Color.parseColor(category.colorHex)),
                        trackColor = Color(0xFF2D2D2D),
                        modifier = Modifier
                            .weight(1f)
                            .height(8.dp)
                            .background(Color.Transparent, RoundedCornerShape(4.dp))
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        "$${String.format(Locale.US, "%.1f", amount)}",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }
        }
    }
}

@Composable
fun ExpenseList(expenses: List<ExpenseEntry>, onDelete: (ExpenseEntry) -> Unit) {
    if (expenses.isEmpty()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(48.dp),
            contentAlignment = Alignment.Center
        ) {
            Text("No expenses logged yet.", color = Color.Gray)
        }
    } else {
        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(expenses.reversed()) { expense ->
                ExpenseRow(expense, onDelete = { onDelete(expense) })
            }
        }
    }
}

@Composable
fun ExpenseRow(expense: ExpenseEntry, onDelete: () -> Unit) {
    val formatter = SimpleDateFormat("MMM dd, yyyy", Locale.US)
    val dateStr = formatter.format(Date(expense.dateEpoch))
    
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .background(
                            Color(android.graphics.Color.parseColor(expense.category.colorHex)),
                            RoundedCornerShape(6.dp)
                        )
                )
                Spacer(modifier = Modifier.width(12.dp))
                Column {
                    Text(
                        expense.title,
                        fontWeight = FontWeight.Medium,
                        color = Color.White
                    )
                    Text(
                        dateStr,
                        fontSize = 12.sp,
                        color = Color.Gray
                    )
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "$${String.format(Locale.US, "%.2f", expense.amount)}",
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    fontSize = 16.sp
                )
                Spacer(modifier = Modifier.width(16.dp))
                Icon(
                    Icons.Default.Delete,
                    contentDescription = "Delete",
                    tint = Color.Red.copy(alpha = 0.8f),
                    modifier = Modifier
                        .size(20.dp)
                        .clickable { onDelete() }
                )
            }
        }
    }
}

@Composable
fun AddExpenseDialog(onDismiss: () -> Unit, onSave: (String, Double, ExpenseCategory) -> Unit) {
    var title by remember { mutableStateOf("") }
    var amountStr by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf(ExpenseCategory.FOOD) }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Column(
                modifier = Modifier.padding(24.dp)
            ) {
                Text(
                    "Add New Expense",
                    fontWeight = FontWeight.Bold,
                    fontSize = 20.sp,
                    color = Color.White,
                    modifier = Modifier.padding(bottom = 16.dp)
                )
                
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("Title") },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color(0xFF4DABF7),
                        unfocusedBorderColor = Color.Gray,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White
                    ),
                    modifier = Modifier.fillMaxWidth()
                )
                
                Spacer(modifier = Modifier.height(12.dp))
                
                OutlinedTextField(
                    value = amountStr,
                    onValueChange = { amountStr = it },
                    label = { Text("Amount ($)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color(0xFF4DABF7),
                        unfocusedBorderColor = Color.Gray,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White
                    ),
                    modifier = Modifier.fillMaxWidth()
                )
                
                Spacer(modifier = Modifier.height(16.dp))
                
                Text("Category", fontSize = 12.sp, color = Color.Gray)
                Spacer(modifier = Modifier.height(8.dp))
                
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    ExpenseCategory.values().forEach { category ->
                        val isSelected = selectedCategory == category
                        val color = Color(android.graphics.Color.parseColor(category.colorHex))
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .background(
                                    if (isSelected) color else Color(0xFF2D2D2D),
                                    RoundedCornerShape(18.dp)
                                )
                                .clickable { selectedCategory = category },
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                category.displayName.substring(0, 1),
                                color = if (isSelected) Color.Black else Color.White,
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp
                            )
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(24.dp))
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) {
                        Text("Cancel", color = Color.Gray)
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        onClick = {
                            val amount = amountStr.toDoubleOrNull() ?: 0.0
                            if (title.isNotBlank() && amount > 0.0) {
                                onSave(title, amount, selectedCategory)
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF4DABF7))
                    ) {
                        Text("Save", color = Color.White)
                    }
                }
            }
        }
    }
}
