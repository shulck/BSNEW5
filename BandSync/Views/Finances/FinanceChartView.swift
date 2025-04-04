import SwiftUI
import Charts

struct FinanceChartView: View {
    let records: [FinanceRecord]
    @State private var chartType: ChartType = .monthly
    @State private var showLegend = true
    @State private var selectedIndex: Int? = nil

    enum ChartType: String, CaseIterable {
        case monthly = "По месяцам"
        case category = "По категориям"
    }

    // Группировка записей по месяцам
    private var monthlyRecords: [(month: Date, income: Double, expense: Double)] {
        let calendar = Calendar.current

        // Группировка записей по месяцам
        let groupedRecords = Dictionary(grouping: records) { record in
            calendar.date(from: calendar.dateComponents([.year, .month], from: record.date)) ?? Date()
        }

        // Трансформация сгруппированных данных
        let processedRecords = groupedRecords.map { (month, monthRecords) -> (month: Date, income: Double, expense: Double) in
            let income = monthRecords
                .filter { $0.type == .income }
                .reduce(0.0) { $0 + $1.amount }

            let expense = monthRecords
                .filter { $0.type == .expense }
                .reduce(0.0) { $0 + $1.amount }

            return (month: month, income: income, expense: expense)
        }

        // Сортировка по месяцам
        return processedRecords.sorted { $0.month < $1.month }
    }

    // Группировка записей по категориям
    private var categoryRecords: [(category: String, amount: Double, isIncome: Bool)] {
        // Группировка по категориям
        let incomeByCategory = Dictionary(grouping: records.filter { $0.type == .income }) { $0.category }
            .mapValues { records in records.reduce(0) { $0 + $1.amount } }
            .map { (category: $0.key, amount: $0.value, isIncome: true) }

        let expenseByCategory = Dictionary(grouping: records.filter { $0.type == .expense }) { $0.category }
            .mapValues { records in records.reduce(0) { $0 + $1.amount } }
            .map { (category: $0.key, amount: $0.value, isIncome: false) }

        // Объединение и сортировка
        return (incomeByCategory + expenseByCategory).sorted { $0.amount > $1.amount }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок с информацией
            VStack(spacing: 4) {
                Text("Финансовая статистика")
                    .font(.title2.bold())

                Text("Всего записей: \(records.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)

            // Переключатель типа графика с улучшенным дизайном
            VStack(spacing: 15) {
                HStack {
                    ForEach(ChartType.allCases, id: \.self) { type in
                        Button {
                            withAnimation {
                                chartType = type
                                // Сбрасываем выбор точки при смене графика
                                selectedIndex = nil
                            }
                        } label: {
                            Text(type.rawValue)
                                .font(.subheadline)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(chartType == type ? Color.blue : Color.clear)
                                        .shadow(color: chartType == type ? Color.blue.opacity(0.3) : Color.clear, radius: 3, x: 0, y: 2)
                                )
                                .foregroundColor(chartType == type ? .white : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .animation(.spring(response: 0.3), value: chartType)
                    }
                }

                // Карточка с общими показателями
                HStack(spacing: 20) {
                    statCard(title: "Доходы", value: totalIncome, color: .green)
                    statCard(title: "Расходы", value: totalExpense, color: .red)
                    statCard(title: "Баланс", value: profit, color: profit >= 0 ? .green : .red)
                }
            }
            .padding()

            // Разделитель между переключателями и графиком
            Divider()
                .padding(.horizontal)

            ScrollView {
                VStack(spacing: 20) {
                    if records.isEmpty {
                        emptyStateView
                    } else {
                        switch chartType {
                        case .monthly:
                            improvedMonthlyChartView
                        case .category:
                            improvedCategoryChartView
                        }
                    }
                }
                .padding()
            }

            // Легенда
            if showLegend && !records.isEmpty {
                legendView
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.secondary.opacity(0.05).ignoresSafeArea())
    }

    // Карточка статистики
    private func statCard(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(Int(value))")
                .font(.headline)
                .foregroundColor(color)

            // Линия-индикатор
            Rectangle()
                .fill(color)
                .frame(width: 30, height: 3)
                .cornerRadius(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }

    // Общие рассчитываемые значения
    private var totalIncome: Double {
        records.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        records.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var profit: Double {
        totalIncome - totalExpense
    }

    // Пустое состояние
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.7))
                .padding(.top, 40)

            Text("Нет данных для отображения")
                .font(.headline)
                .foregroundColor(.gray)

            Text("Добавьте финансовые операции, чтобы увидеть статистику")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray.opacity(0.7))
                .padding(.horizontal)
                .padding(.bottom, 20)
        }
    }

    // Улучшенный график по месяцам
    private var improvedMonthlyChartView: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Заголовок с периодом
            if !monthlyRecords.isEmpty {
                let startDate = monthlyRecords.last?.month ?? Date()
                let endDate = monthlyRecords.first?.month ?? Date()

                Text("Финансы с \(monthFormatter.string(from: startDate)) по \(monthFormatter.string(from: endDate))")
                    .font(.headline)
                    .padding(.horizontal)
            }

            if monthlyRecords.isEmpty {
                Text("Нет данных для выбранного периода")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // График
                ZStack(alignment: .top) {
                    // Основной график
                    Chart {
                        ForEach(monthlyRecords.indices, id: \.self) { index in
                            let record = monthlyRecords[index]

                            // Доходы
                            BarMark(
                                x: .value("Месяц", record.month, unit: .month),
                                y: .value("Доход", record.income)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green.opacity(0.7), .green.opacity(0.9)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .cornerRadius(4)
                            .opacity(selectedIndex == nil || selectedIndex == index ? 1 : 0.5)

                            // Расходы (отрицательные значения)
                            BarMark(
                                x: .value("Месяц", record.month, unit: .month),
                                y: .value("Расход", -record.expense)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red.opacity(0.7), .red.opacity(0.9)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .cornerRadius(4)
                            .opacity(selectedIndex == nil || selectedIndex == index ? 1 : 0.5)
                        }

                        // Добавляем линию баланса
                        if monthlyRecords.count > 1 {
                            LineMark(
                                x: .value("Месяц", monthlyRecords[0].month, unit: .month),
                                y: .value("Баланс", monthlyRecords[0].income - monthlyRecords[0].expense)
                            )
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .opacity(0.8)

                            ForEach(1..<monthlyRecords.count, id: \.self) { index in
                                LineMark(
                                    x: .value("Месяц", monthlyRecords[index].month, unit: .month),
                                    y: .value("Баланс", monthlyRecords[index].income - monthlyRecords[index].expense)
                                )
                                .foregroundStyle(.blue)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                .opacity(0.8)
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(shortMonthFormatter.string(from: date))
                                }
                            }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let xPosition = value.location.x
                                            let chartWidth = geometry.size.width
                                            let stepWidth = chartWidth / CGFloat(monthlyRecords.count)

                                            // Определяем индекс выбранной точки
                                            let index = min(max(Int(xPosition / stepWidth), 0), monthlyRecords.count - 1)
                                            selectedIndex = index
                                        }
                                        .onEnded { _ in
                                            selectedIndex = nil
                                        }
                                )
                        }
                    }
                    .frame(height: 300)
                    .padding(.vertical)
                    .animation(.easeInOut, value: selectedIndex)

                    // Отображаем детали для выбранного месяца
                    if let selectedIndex = selectedIndex, selectedIndex < monthlyRecords.count {
                        let record = monthlyRecords[selectedIndex]

                        VStack(spacing: 8) {
                            Text(monthFormatter.string(from: record.month))
                                .font(.headline)

                            HStack(spacing: 20) {
                                Label("+\(Int(record.income))", systemImage: "arrow.down")
                                    .foregroundColor(.green)

                                Label("-\(Int(record.expense))", systemImage: "arrow.up")
                                    .foregroundColor(.red)

                                Label("\(Int(record.income - record.expense))", systemImage: "equal")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.bottom)
            }
        }
    }

    // Улучшенный график по категориям
    private var improvedCategoryChartView: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Селектор типа финансов для категорий
            HStack {
                Text("Категории:")
                    .font(.headline)

                Picker("", selection: Binding(
                    get: { self.categoryFilter },
                    set: { newFilter in
                        withAnimation {
                            self.categoryFilter = newFilter
                            self.selectedIndex = nil
                        }
                    }
                )) {
                    Text("Все").tag(CategoryFilter.all)
                    Text("Доходы").tag(CategoryFilter.income)
                    Text("Расходы").tag(CategoryFilter.expense)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            // Панель доходов/расходов
            HStack(spacing: 10) {
                // Доходы
                VStack(alignment: .leading, spacing: 5) {
                    Text("Доходы")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(Int(totalIncome))")
                        .font(.headline)
                        .foregroundColor(.green)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: geo.size.width, height: 6)
                                .cornerRadius(3)

                            Rectangle()
                                .fill(Color.green)
                                .frame(width: totalIncome > 0 && profit > 0
                                       ? geo.size.width * CGFloat(totalIncome / (totalIncome + totalExpense))
                                       : 0,
                                       height: 6)
                                .cornerRadius(3)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                )

                // Расходы
                VStack(alignment: .leading, spacing: 5) {
                    Text("Расходы")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(Int(totalExpense))")
                        .font(.headline)
                        .foregroundColor(.red)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: geo.size.width, height: 6)
                                .cornerRadius(3)

                            Rectangle()
                                .fill(Color.red)
                                .frame(width: totalExpense > 0 && profit < 0
                                       ? geo.size.width * CGFloat(totalExpense / (totalIncome + totalExpense))
                                       : 0,
                                       height: 6)
                                .cornerRadius(3)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                )
            }
            .padding(.horizontal)

            if filteredCategoryRecords.isEmpty {
                Text("Нет данных для выбранного типа")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                // График категорий
                Chart {
                    ForEach(filteredCategoryRecords.indices, id: \.self) { index in
                        let record = filteredCategoryRecords[index]

                        BarMark(
                            x: .value("Сумма", record.amount),
                            y: .value("Категория", record.category)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    record.isIncome ? .green.opacity(0.7) : .red.opacity(0.7),
                                    record.isIncome ? .green : .red
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(6)
                        .opacity(selectedIndex == nil || selectedIndex == index ? 1 : 0.5)
                        .annotation(position: .trailing) {
                            Text("\(Int(record.amount))")
                                .font(.caption)
                                .foregroundColor(record.isIncome ? .green : .red)
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.9))
                                )
                        }
                    }
                }
                .chartXAxis(.automatic)
                .chartYAxis {
                    AxisMarks { value in
                        if let category = value.as(String.self) {
                            AxisValueLabel {
                                HStack(spacing: 4) {
                                    let isIncome = filteredCategoryRecords.first { $0.category == category }?.isIncome ?? false
                                    Circle()
                                        .fill(isIncome ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)

                                    Text(category)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let yPosition = value.location.y
                                        let chartHeight = geometry.size.height
                                        let stepHeight = chartHeight / CGFloat(filteredCategoryRecords.count)

                                        // Определяем индекс выбранной категории
                                        let index = min(max(Int(yPosition / stepHeight), 0), filteredCategoryRecords.count - 1)
                                        selectedIndex = index
                                    }
                                    .onEnded { _ in
                                        selectedIndex = nil
                                    }
                            )
                    }
                }
                .frame(height: CGFloat(filteredCategoryRecords.count * 40))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .animation(.easeInOut, value: selectedIndex)
                .padding(.bottom)

                // Если выбрана категория, показываем подробности
                if let selectedIndex = selectedIndex, selectedIndex < filteredCategoryRecords.count {
                    let record = filteredCategoryRecords[selectedIndex]

                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.category)
                                .font(.headline)

                            Text(record.isIncome ? "Доход" : "Расход")
                                .font(.subheadline)
                                .foregroundColor(record.isIncome ? .green : .red)
                        }

                        Spacer()

                        Text("\(Int(record.amount))")
                            .font(.title3.bold())
                            .foregroundColor(record.isIncome ? .green : .red)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(record.isIncome ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    )
                    .padding(.horizontal)
                    .transition(.scale.combined(with: .opacity))
                }

                // Дополнительная информация о транзакциях в выбранной категории
                if let selectedIndex = selectedIndex, selectedIndex < filteredCategoryRecords.count {
                    let record = filteredCategoryRecords[selectedIndex]

                    let categoryTransactions = records.filter {
                        $0.category == record.category &&
                        (record.isIncome ? $0.type == .income : $0.type == .expense)
                    }

                    Text("Последние транзакции")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)

                    ForEach(categoryTransactions.prefix(3)) { transaction in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(transaction.details.isEmpty ? "Без описания" : transaction.details)")
                                    .fontWeight(.medium)

                                Text(dateFormatter.string(from: transaction.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("\(Int(transaction.amount))")
                                .fontWeight(.semibold)
                                .foregroundColor(transaction.type == .income ? .green : .red)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(Color.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // Легенда
    private var legendView: some View {
        HStack {
            switch chartType {
            case .monthly:
                legendItem(color: .green, text: "Доходы")
                legendItem(color: .red, text: "Расходы")
                legendItem(color: .blue, text: "Баланс")
            case .category:
                switch categoryFilter {
                case .all:
                    legendItem(color: .green, text: "Доходы")
                    legendItem(color: .red, text: "Расходы")
                case .income:
                    legendItem(color: .green, text: "Доходы")
                case .expense:
                    legendItem(color: .red, text: "Расходы")
                }
            }

            Spacer()

            // Кнопка скрыть/показать легенду
            Button {
                withAnimation {
                    showLegend.toggle()
                }
            } label: {
                Image(systemName: showLegend ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
    }

    // Элемент легенды
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.trailing, 8)
    }

    // Новые свойства для улучшенных графиков

    // Фильтр категорий
    @State private var categoryFilter: CategoryFilter = .all

    enum CategoryFilter {
        case all
        case income
        case expense
    }

    // Отфильтрованные записи категорий
    private var filteredCategoryRecords: [(category: String, amount: Double, isIncome: Bool)] {
        switch categoryFilter {
        case .all:
            return categoryRecords
        case .income:
            return categoryRecords.filter { $0.isIncome }
        case .expense:
            return categoryRecords.filter { !$0.isIncome }
        }
    }

    // Форматтеры для дат
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    private var shortMonthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}
