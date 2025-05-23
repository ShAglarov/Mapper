//
//  ViewController.swift
//  Mapper
//
//  Created by Murad Tataev on 23.05.2025.
//

import UIKit
import MapKit
import CoreLocation

// Структура для хранения данных точки (название и координаты), соответствует Codable для сохранения в UserDefaults
struct SavedPoint: Codable {
    let name: String
    let latitude: Double
    let longitude: Double

    // Вычисляемое свойство для получения координаты CLLocationCoordinate2D из сохранённых значений
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

class ViewController: UIViewController, MKMapViewDelegate, UITableViewDataSource, UITableViewDelegate {

    // UI-элементы: карта и таблица
    private let mapView = MKMapView()
    private let tableView = UITableView()
    private var isTableViewHidden = false
    private var tableViewHeightConstraint: NSLayoutConstraint?

    // Массив сохранённых точек (название + координаты)
    private var savedPoints: [SavedPoint] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Настройка карты и таблицы
        setupUI()
        mapView.delegate = self               // Делаем ViewController делегатом карты (для отрисовки наложений)
        tableView.dataSource = self
        tableView.delegate = self

        loadPoints()                          // Загрузка сохранённых точек из UserDefaults в savedPoints
        addSavedPointsToMap()                // Отображение загруженных точек на карте и в таблице

        // Добавляем распознавание долгого нажатия на карту для добавления новой точки
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleMapLongPress(_:)))
        longPressRecognizer.minimumPressDuration = 0.5  // полсекунды для срабатывания
        mapView.addGestureRecognizer(longPressRecognizer)
    }

    @objc private func mapTypeChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            mapView.mapType = .standard
        case 1:
            mapView.mapType = .satellite
        case 2:
            mapView.mapType = .hybrid
        default:
            break
        }
    }

    @objc private func toggleListVisibility() {
        isTableViewHidden.toggle()
        // Анимация: скрыть или показать таблицу
        UIView.animate(withDuration: 0.3) {
            self.tableView.alpha = self.isTableViewHidden ? 0 : 1
        }
        // Меняем текст на кнопке
        let newTitle = isTableViewHidden ? "Показать список" : "Скрыть список"
        (view.subviews.first(where: { $0 is UIButton && ($0 as! UIButton).currentTitle?.contains("список") == true }) as? UIButton)?.setTitle(newTitle, for: .normal)
    }

    // Функция настройки интерфейса: размещаем MKMapView и UITableView на экране
    private func setupUI() {

        view.addSubview(mapView)
        view.addSubview(tableView)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        // Карта занимает верхнюю часть экрана (60% высоты), таблица — оставшуюся нижнюю часть
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),

            tableView.topAnchor.constraint(equalTo: mapView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        // Регистрируем ячейку таблицы стандартного типа с подзаголовком (Title и Subtitle)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PointCell")
        tableView.tableFooterView = UIView()  // убираем разделительные линии под списком
        // Добавляем кнопку "Добавить" для ввода координат вручную (в правом верхнем углу карты)
        let addButton = UIButton(type: .system)
        addButton.setTitle("Добавить точку", for: .normal)
        addButton.addTarget(self, action: #selector(addPointByCoordinates), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addButton)
        // Размещаем кнопку на карте (правый верхний угол с отступом)
        NSLayoutConstraint.activate([
            addButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])

        let editButton = UIButton(type: .system)
        editButton.setTitle("Редактировать", for: .normal)
        editButton.addTarget(self, action: #selector(toggleEditMode), for: .touchUpInside)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editButton)
        NSLayoutConstraint.activate([
            editButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            editButton.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -8)
        ])

        // 1. Создаём сегмент для выбора типа карты
        let mapTypeControl = UISegmentedControl(items: ["Стандарт", "Спутник", "Гибрид"])
        mapTypeControl.selectedSegmentIndex = 0 // По умолчанию "Стандарт"
        mapTypeControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapTypeControl)


        NSLayoutConstraint.activate([
            mapTypeControl.topAnchor.constraint(equalTo: view.topAnchor, constant: 80),
            mapTypeControl.heightAnchor.constraint(equalToConstant: 30),
            mapTypeControl.widthAnchor.constraint(equalToConstant: 260),
            mapTypeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        // 3. Обработчик изменения режима карты
        mapTypeControl.addTarget(self, action: #selector(mapTypeChanged(_:)), for: .valueChanged)

        let toggleListButton = UIButton(type: .system)
        toggleListButton.setTitle("Показать список", for: .normal)
        toggleListButton.translatesAutoresizingMaskIntoConstraints = false
        toggleListButton.backgroundColor = .white
        toggleListButton.layer.cornerRadius = 8
        toggleListButton.layer.shadowOpacity = 0.2
        toggleListButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        toggleListButton.addTarget(self, action: #selector(toggleListVisibility), for: .touchUpInside)
        view.addSubview(toggleListButton)

        NSLayoutConstraint.activate([
            toggleListButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            toggleListButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toggleListButton.widthAnchor.constraint(equalToConstant: 140),
            toggleListButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        tableViewHeightConstraint = tableView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4)
        tableViewHeightConstraint?.isActive = true


        let center = CLLocationCoordinate2D(latitude: 42.9778, longitude: 47.5147)
        let region = MKCoordinateRegion(center: center, latitudinalMeters: 9000, longitudinalMeters: 9000)
        mapView.setRegion(region, animated: false)
    }
    

    @objc private func toggleEditMode() {
        tableView.setEditing(!tableView.isEditing, animated: true)
    }

    // Загрузка сохранённых точек из UserDefaults
    private func loadPoints() {
        let defaults = UserDefaults.standard
        if let savedData = defaults.data(forKey: "SavedPoints"),
           let decodedPoints = try? JSONDecoder().decode([SavedPoint].self, from: savedData) {
            savedPoints = decodedPoints
        }
    }

    // Сохранение текущего массива точек в UserDefaults
    private func savePoints() {
        let defaults = UserDefaults.standard
        if let encodedData = try? JSONEncoder().encode(savedPoints) {
            defaults.set(encodedData, forKey: "SavedPoints")
        }
    }

    // Отображение всех загруженных точек на карте и позиционирование карты
    private func addSavedPointsToMap() {
        for point in savedPoints {
            // Создаём аннотацию для каждой точки
            let annotation = MKPointAnnotation()
            annotation.title = point.name
            annotation.coordinate = point.coordinate
            mapView.addAnnotation(annotation)
            // Создаём круговое наложение (MKCircle) радиусом 100 м для подсветки точки
            let circleOverlay = MKCircle(center: point.coordinate, radius: 10)
            mapView.addOverlay(circleOverlay)
        }
        tableView.reloadData()
        // Если есть сохранённые точки, масштабируем карту, чтобы были видны все аннотации
        if !savedPoints.isEmpty {
            mapView.showAnnotations(mapView.annotations, animated: false)
        }
    }

    // MARK: - Обработчики пользовательских действий

    // Обработчик долгого нажатия на карту – начало процесса добавления новой точки
    @objc private func handleMapLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let touchPoint = gesture.location(in: mapView)
            let coord = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            // Показываем UIAlert с полем ввода для названия точки
            let alert = UIAlertController(title: "Новая точка", message: "Введите название точки", preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "Название"
            }
            // Кнопка "Сохранить" добавляет точку с введённым именем (или стандартным именем, если не заполнено)
            alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { _ in
                let nameInput = alert.textFields?.first?.text ?? ""
                let pointName = nameInput.isEmpty ? "Точка \(self.savedPoints.count + 1)" : nameInput
                self.addPoint(name: pointName, latitude: coord.latitude, longitude: coord.longitude)
            }))
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }

    // Обработчик нажатия кнопки "Добавить точку" – диалог ввода координат вручную
    @objc private func addPointByCoordinates() {
        let alert = UIAlertController(title: "Добавить точку", message: "Введите координаты и название", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Название" }
        alert.addTextField { $0.placeholder = "Широта (Latitude)" }
        alert.addTextField { $0.placeholder = "Долгота (Longitude)" }
        alert.addAction(UIAlertAction(title: "Добавить", style: .default, handler: { _ in
            guard let textFields = alert.textFields,
                  textFields.count >= 3 else { return }
            let nameInput = textFields[0].text ?? ""
            let latText = textFields[1].text ?? ""
            let lonText = textFields[2].text ?? ""
            // Парсим координаты из текста
            guard let latitude = Double(latText), let longitude = Double(lonText) else {
                print("Некорректные координаты")
                return
            }
            let pointName = nameInput.isEmpty ? "Точка \(self.savedPoints.count + 1)" : nameInput
            self.addPoint(name: pointName, latitude: latitude, longitude: longitude)
        }))
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // Функция добавления новой точки на карту, в массив и в UserDefaults
    private func addPoint(name: String, latitude: Double, longitude: Double) {
        let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        // Создаём и добавляем аннотацию (метку) на карту
        let annotation = MKPointAnnotation()
        annotation.title = name
        annotation.coordinate = coord
        mapView.addAnnotation(annotation)
        // Создаём круговое наложение (радиус 100 м) для цветной подсветки точки
        let circleOverlay = MKCircle(center: coord, radius: 100)
        mapView.addOverlay(circleOverlay)
        // Добавляем новую точку в массив данных и сохраняем в UserDefaults
        let newPoint = SavedPoint(name: name, latitude: latitude, longitude: longitude)
        savedPoints.append(newPoint)
        savePoints()
        tableView.reloadData()
        // Центрируем карту на добавленной точке (с небольшим масштабом вокруг)
        let region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        mapView.setRegion(region, animated: true)
    }

    // MARK: - UITableViewDataSource и UITableViewDelegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return savedPoints.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Используем стандартную ячейку с стилем Subtitle для отображения имени и координат точки
        let cell = tableView.dequeueReusableCell(withIdentifier: "PointCell", for: indexPath)
        let point = savedPoints[indexPath.row]
        cell.textLabel?.text = point.name
        // Форматируем координаты до 4 знаков после запятой для удобочитаемости
        cell.detailTextLabel?.text = String(format: "Lat: %.4f, Lon: %.4f", point.latitude, point.longitude)
        return cell
    }

    // Пользователь выбрал точку из списка – перемещаем карту к этой точке
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let point = savedPoints[indexPath.row]
        let coord = point.coordinate
        // Центрируем карту на выбранной точке
        let region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.0010, longitudeDelta: 0.0010))
        mapView.setRegion(region, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let point = savedPoints[indexPath.row]
            // Удаляем аннотацию с карты
            if let annotation = mapView.annotations.first(where: {
                $0.coordinate.latitude == point.latitude && $0.coordinate.longitude == point.longitude
            }) {
                mapView.removeAnnotation(annotation)
            }
            // Удаляем overlay с карты
            if let overlay = mapView.overlays.first(where: { overlay in
                guard let circle = overlay as? MKCircle else { return false }
                return abs(circle.coordinate.latitude - point.latitude) < 1e-6 && abs(circle.coordinate.longitude - point.longitude) < 1e-6
            }) {
                mapView.removeOverlay(overlay)
            }
            // Удаляем из данных и UserDefaults
            savedPoints.remove(at: indexPath.row)
            savePoints()
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let edit = UIContextualAction(style: .normal, title: "Редакт.") { [weak self] (action, view, completionHandler) in
            guard let self = self else { return }
            let point = self.savedPoints[indexPath.row]
            let alert = UIAlertController(title: "Редактировать точку", message: "Измените название точки", preferredStyle: .alert)
            alert.addTextField { $0.text = point.name }
            alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { _ in
                guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
                self.savedPoints[indexPath.row] = SavedPoint(name: newName, latitude: point.latitude, longitude: point.longitude)
                self.savePoints()
                self.tableView.reloadRows(at: [indexPath], with: .automatic)
                // Также обновим аннотацию на карте
                if let annotation = self.mapView.annotations.first(where: {
                    $0.coordinate.latitude == point.latitude && $0.coordinate.longitude == point.longitude
                }) as? MKPointAnnotation {
                    annotation.title = newName
                }
            }))
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            self.present(alert, animated: true)
            completionHandler(true)
        }
        edit.backgroundColor = .orange
        return UISwipeActionsConfiguration(actions: [edit])
    }


    // MARK: - MKMapViewDelegate (отрисовка наложений)

    // Метод делегата для предоставления рендерера (MKOverlayRenderer) для накладываемых объектов (MKCircle)
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        // Проверяем, является ли наложение кругом (MKCircle)
        guard let circleOverlay = overlay as? MKCircle else {
            return MKOverlayRenderer(overlay: overlay)
        }
        // Создаём рендерер для круга
        let circleRenderer = MKCircleRenderer(circle: circleOverlay)
        // Определяем цвет заливки и обводки: чередуем красный и синий для разных точек (пример)
        if let index = savedPoints.firstIndex(where: { abs($0.latitude - circleOverlay.coordinate.latitude) < 1e-6 && abs($0.longitude - circleOverlay.coordinate.longitude) < 1e-6 }) {
            let color: UIColor = (index % 2 == 0) ? .red : .blue
            circleRenderer.fillColor = color.withAlphaComponent(0.3)  // полупрозрачная заливка
            circleRenderer.strokeColor = color                        // обводка того же цвета
        } else {
            // Если по какой-то причине индекс не найден, используем красный по умолчанию
            circleRenderer.fillColor = UIColor.red.withAlphaComponent(0.3)
            circleRenderer.strokeColor = .red
        }
        circleRenderer.lineWidth = 1.0
        return circleRenderer
    }
}

