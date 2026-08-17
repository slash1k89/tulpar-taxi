class City {
  final String id;
  final String name;
  final bool isActive;

  const City({
    required this.id,
    required this.name,
    this.isActive = true,
  });
}

// Список городов (Есиль по умолчанию)
const List<City> availableCities = [
  City(id: 'esil', name: 'Есиль'),
  City(id: 'astana', name: 'Астана'),
  City(id: 'arkalyk', name: 'Аркалык'),
];