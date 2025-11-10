import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

// --- CONFIGURACIÓN ---
const String _apiBaseUrl = "https://app-251026210414.azurewebsites.net/api";
// --------------------

void main() {
  runApp(const MyApp());
}

// --- Modelos de Datos ---
class Product {
  final int id;
  final String nombre;
  final String descripcion;
  final double precio;
  int stock; // Hacerlo modificable para el carrito
  final String nombreEmpresa;

  Product({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.stock,
    required this.nombreEmpresa,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      stock: json['stock'] ?? 0,
      nombreEmpresa: json['nombreEmpresa'] ?? 'Desconocida',
    );
  }
}

class EmpresaDto { /* ... código sin cambios ... */
 final String id;
  final String email;
  final String nombreCompleto;
  final int cantidadProductos;
  EmpresaDto({ required this.id, required this.email, required this.nombreCompleto, required this.cantidadProductos });
   factory EmpresaDto.fromJson(Map<String, dynamic> json) {
    return EmpresaDto( id: json['id'] ?? '', email: json['email'] ?? '', nombreCompleto: json['nombreCompleto'] ?? '', cantidadProductos: json['cantidadProductos'] ?? 0, );
  }
}

// ¡NUEVO! Modelo para item en el carrito
class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.precio * quantity;
}

// ¡NUEVO! Modelo para enviar la orden a la API (coincide con OrdenCreateDto)
class OrderCreateRequest {
  final List<OrderItemCreateRequest> items;

  OrderCreateRequest({required this.items});

  Map<String, dynamic> toJson() => {
        'items': items.map((item) => item.toJson()).toList(),
      };
}
class OrderItemCreateRequest {
  final int productoId;
  final int cantidad;

  OrderItemCreateRequest({required this.productoId, required this.cantidad});

   Map<String, dynamic> toJson() => {
        'productoId': productoId,
        'cantidad': cantidad,
      };
}


// --- Servicios API ---
class BaseApiService {
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (includeAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }
}

class AuthService extends BaseApiService { /* ... código sin cambios ... */
 final _tokenKey = 'jwt_token';
  final _roleKey = 'user_role';
  Future<Map<String, dynamic>?> login(String email, String password) async {
    final url = Uri.parse('$_apiBaseUrl/Auth/login');
    try {
      final response = await http.post( url, headers: await _getHeaders(includeAuth: false), body: json.encode({'email': email, 'password': password}), );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['token'];
        final List<dynamic> roles = data['roles'] ?? [];
        final String userRole = roles.isNotEmpty ? roles[0] : 'User';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_roleKey, userRole);
        print("Login exitoso. Token y Rol ($userRole) guardados.");
        return data;
      } else { print('Error en login: Status Code ${response.statusCode} Body: ${response.body}'); return null; }
    } catch (e) { print('Error de conexión: $e'); return null; }
  }
  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    print("Revisando login. Token encontrado: ${token != null}");
    return token != null;
  }
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    print("Sesión cerrada. Token y Rol borrados.");
  }
}

class ProductService extends BaseApiService {
  Future<List<Product>> fetchProducts() async {
    final url = Uri.parse('$_apiBaseUrl/Productos');
    try {
      // Usamos includeAuth: false porque este endpoint es público
      final response = await http.get(url, headers: await _getHeaders(includeAuth: false));
      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        List<Product> products = body.map((dynamic item) => Product.fromJson(item as Map<String, dynamic>)).toList();
        print("Productos públicos obtenidos: ${products.length}");
        return products;
      } else {
        print('Error al obtener productos públicos: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error de conexión al obtener productos públicos: $e');
      return [];
    }
  }
}

class AdminService extends BaseApiService { 
 Future<bool> crearEmpresa(String email, String password, String nombreCompleto) async {
    final url = Uri.parse('$_apiBaseUrl/Admin/crear-empresa');
    final headers = await _getHeaders();
    try {
      final response = await http.post( url, headers: headers, body: json.encode({'email': email, 'password': password, 'nombreCompleto': nombreCompleto}), );
      if (response.statusCode == 201) { print("Empresa creada exitosamente."); return true; }
      else { print('Error al crear empresa: ${response.body}'); return false; }
    } catch (e) { print('Error de conexión al crear empresa: $e'); return false; }
  }
  Future<List<EmpresaDto>> getEmpresas() async {
      final url = Uri.parse('$_apiBaseUrl/Admin/empresas');
      final headers = await _getHeaders();
      try {
          final response = await http.get(url, headers: headers);
          if (response.statusCode == 200) {
              List<dynamic> body = json.decode(response.body);
              List<EmpresaDto> empresas = body.map((dynamic item) => EmpresaDto.fromJson(item as Map<String, dynamic>)).toList();
              print("Empresas obtenidas: ${empresas.length}");
              return empresas;
          } else { print('Error al obtener empresas: ${response.body}'); return []; }
      } catch (e) { print('Error de conexión al obtener empresas: $e'); return []; }
  }
}

class EmpresaService extends BaseApiService { /* ... código sin cambios ... */
 Future<List<Product>> getMisProductos() async {
    final url = Uri.parse('$_apiBaseUrl/Empresa/productos');
    final headers = await _getHeaders();
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        List<Product> products = body.map((dynamic item) => Product.fromJson(item as Map<String, dynamic>)).toList();
        print("Productos de la empresa obtenidos: ${products.length}");
        return products;
      } else { print('Error al obtener mis productos: ${response.body}'); return []; }
    } catch (e) { print('Error de conexión al obtener mis productos: $e'); return []; }
  }
  Future<bool> crearProducto(String nombre, String descripcion, double precio, int stock) async {
     final url = Uri.parse('$_apiBaseUrl/Empresa/productos');
     final headers = await _getHeaders();
     try {
       final response = await http.post( url, headers: headers, body: json.encode({ 'nombre': nombre, 'descripcion': descripcion, 'precio': precio, 'stock': stock, }), );
       if (response.statusCode == 201) { print("Producto creado exitosamente."); return true; }
       else { print('Error al crear producto: ${response.body}'); return false; }
     } catch (e) { print('Error de conexión al crear producto: $e'); return false; }
  }
}

// ¡NUEVO! Servicio de Órdenes
class OrderService extends BaseApiService {
  Future<bool> crearOrden(OrderCreateRequest orden) async {
    final url = Uri.parse('$_apiBaseUrl/Ordenes');
    final headers = await _getHeaders(); // Necesita token de User
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(orden.toJson()), // Usamos el toJson() del DTO
      );
      if (response.statusCode == 201) { // 201 Created
        print("Orden creada exitosamente.");
        return true;
      } else {
        print('Error al crear orden: ${response.body}');
        // Intentar decodificar el error de la API (ej. stock insuficiente)
        String errorMessage = "Error desconocido al crear la orden.";
        try {
          final errorBody = json.decode(response.body);
           // La API devuelve un objeto con 'title' o directamente el mensaje
          errorMessage = errorBody['title'] ?? errorBody.toString();
        } catch (_) {
          errorMessage = response.body; // Si no es JSON, mostrar el cuerpo tal cual
        }
        // Lanzar una excepción para mostrarla en la UI
        throw Exception(errorMessage);
        // return false; // Ya no usamos esto
      }
    } catch (e) {
      print('Error de conexión al crear orden: $e');
      throw Exception('Error de conexión: ${e.toString()}'); // Lanzar excepción
      // return false;
    }
  }
  // TODO: Añadir método para GetMisOrdenes
}


// --- App Principal (Sin cambios) ---
class MyApp extends StatelessWidget { /* ... código sin cambios ... */
const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecommerce App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData( colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true, ),
      home: const AuthCheckScreen(),
    );
  }
}

// --- Pantalla de Chequeo de Auth (Sin cambios) ---
class AuthCheckScreen extends StatefulWidget { /* ... código sin cambios ... */
const AuthCheckScreen({super.key});
  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}
class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final AuthService _authService = AuthService();
  late Future<List<dynamic>> _checkAuthFuture;
  @override
  void initState() { super.initState(); _checkAuthFuture = _checkAuthState(); }
  Future<List<dynamic>> _checkAuthState() async { /* ... */ bool loggedIn = await _authService.isLoggedIn(); String? role; if (loggedIn) { role = await _authService.getUserRole(); } return [loggedIn, role]; }
  void _onLoginSuccess() { setState(() { _checkAuthFuture = _checkAuthState(); }); }
  void _onLogout() { setState(() { _checkAuthFuture = Future.value([false, null]); }); }
  @override
  Widget build(BuildContext context) { /* ... */
  return FutureBuilder<List<dynamic>>(
      future: _checkAuthFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) { return const Scaffold(body: Center(child: CircularProgressIndicator())); }
        if (snapshot.hasData && snapshot.data![0] == true) { final String? userRole = snapshot.data![1] as String?; return HomeScreen(userRole: userRole, onLogout: _onLogout); }
        else { return LoginScreen(onLoginSuccess: _onLoginSuccess); }
      },
    );
  }
}

// --- Pantalla de Login (Sin cambios) ---
class LoginScreen extends StatefulWidget { /* ... código sin cambios ... */
  final VoidCallback onLoginSuccess; const LoginScreen({super.key, required this.onLoginSuccess});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> { /* ... */
final AuthService _authService = AuthService(); final _emailController = TextEditingController(); final _passwordController = TextEditingController(); bool _isLoading = false; String _errorMessage = '';
  @override void dispose() { _emailController.dispose(); _passwordController.dispose(); super.dispose(); }
 Future<void> _handleLogin() async { setState(() { _isLoading = true; _errorMessage = ''; }); final authData = await _authService.login( _emailController.text.trim(), _passwordController.text, ); if (!mounted) return; setState(() { _isLoading = false; }); if (authData != null) { widget.onLoginSuccess(); } else { setState(() { _errorMessage = 'Error en email o contraseña.'; }); } }
 @override Widget build(BuildContext context) { return Scaffold( appBar: AppBar( title: const Text('Iniciar Sesión'), backgroundColor: Colors.deepPurple.shade100, ), body: Center( child: SingleChildScrollView( child: Padding( padding: const EdgeInsets.all(24.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ TextField( controller: _emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)), keyboardType: TextInputType.emailAddress, ), const SizedBox(height: 16), TextField( controller: _passwordController, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)), obscureText: true, ), const SizedBox(height: 24), if (_errorMessage.isNotEmpty) Padding( padding: const EdgeInsets.only(bottom: 16.0), child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 14), textAlign: TextAlign.center,), ), _isLoading ? const CircularProgressIndicator() : ElevatedButton( onPressed: _handleLogin, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 18)), child: const Text('Login'), ), ], ), ), ), ), ); }
}

// --- Pantalla de Home (¡¡MODIFICADA!!) ---
// Ahora incluye el botón del carrito
class HomeScreen extends StatelessWidget {
  final String? userRole;
  final VoidCallback onLogout;
  final AuthService _authService = AuthService();
  // ¡NUEVO! Estado simple para el carrito (solo para el badge)
  // En una app real, usaríamos Provider, Riverpod, etc.
  static final ValueNotifier<int> cartItemCount = ValueNotifier(0);
  static final Map<int, CartItem> _cart = {}; // Carrito simple

  HomeScreen({super.key, required this.userRole, required this.onLogout});

  Future<void> _handleLogout() async {
    _cart.clear(); // Limpiar carrito al salir
    cartItemCount.value = 0;
    await _authService.logout();
    onLogout();
  }

  // Función estática para añadir al carrito desde UserProductList
  static void addToCart(Product product) {
    if (_cart.containsKey(product.id)) {
      if (_cart[product.id]!.quantity < product.stock) {
         _cart[product.id]!.quantity++;
      } else {
        // Mostrar SnackBar (necesitamos BuildContext, lo haremos desde la UI)
        print("Stock máximo alcanzado para ${product.nombre}");
        // Devolvemos -1 para indicar error de stock
        cartItemCount.value = cartItemCount.value; // No cambia
        return; // No añadir más
      }
    } else {
      if(product.stock > 0) { // Solo añadir si hay stock inicial
        _cart[product.id] = CartItem(product: product, quantity: 1);
      } else {
         print("Producto ${product.nombre} sin stock inicial");
         cartItemCount.value = cartItemCount.value; // No cambia
         return; // No añadir
      }
    }
    cartItemCount.value = _cart.length; // Actualizar contador
     print("Añadido al carrito: ${product.nombre}. Total items: ${cartItemCount.value}");
  }


  @override
  Widget build(BuildContext context) {
    String title = 'Home';
    Widget bodyContent;
    List<Widget> actions = [ // Acciones del AppBar
      IconButton(
        tooltip: "Cerrar Sesión",
        icon: const Icon(Icons.logout),
        onPressed: _handleLogout,
      )
    ];

    // Decidimos qué WIDGET mostrar según el rol
    switch (userRole) {
      case 'Admin':
        title = 'Panel de Administrador';
        bodyContent = const AdminPanel();
        break;
      case 'Empresa':
        title = 'Panel de Empresa';
        bodyContent = const EmpresaPanel();
        break;
      case 'User':
      default:
        title = 'Productos Disponibles';
        bodyContent = const UserProductList();
        // ¡NUEVO! Añadir icono de carrito SOLO para User
        actions.insert(0, // Insertar al principio
          ValueListenableBuilder<int>( // Escucha cambios en cartItemCount
             valueListenable: cartItemCount,
             builder: (context, count, child) {
               return Stack( // Para poner el número encima del icono
                 alignment: Alignment.center,
                 children: [
                   IconButton(
                     tooltip: "Ver Carrito",
                     icon: const Icon(Icons.shopping_cart),
                     onPressed: () {
                        // Navegar a la pantalla del carrito
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CartScreen(cart: _cart)),
                        ).then((orderPlaced) {
                          // Si la orden se realizó con éxito (CartScreen devuelve true)
                          if (orderPlaced == true) {
                            _cart.clear(); // Limpiar carrito
                            cartItemCount.value = 0;
                          }
                        });
                     },
                   ),
                   if (count > 0) // Mostrar badge solo si hay items
                     Positioned(
                       right: 8,
                       top: 8,
                       child: Container(
                         padding: const EdgeInsets.all(2),
                         decoration: BoxDecoration(
                           color: Colors.red,
                           borderRadius: BorderRadius.circular(10),
                         ),
                         constraints: const BoxConstraints(minWidth: 16, minHeight: 16,),
                         child: Text(
                           '$count',
                           style: const TextStyle(color: Colors.white, fontSize: 10,),
                           textAlign: TextAlign.center,
                         ),
                       ),
                     ),
                 ],
               );
             }
           )
        );
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions, // Usar la lista de acciones
      ),
      body: bodyContent,
    );
  }
}

// --- Widget para la Lista de Productos del USER (¡¡MODIFICADO!!) ---
// Ahora tiene botón para añadir al carrito
class UserProductList extends StatefulWidget {
  const UserProductList({super.key});
  @override
  State<UserProductList> createState() => _UserProductListState();
}
class _UserProductListState extends State<UserProductList> {
 final ProductService _productService = ProductService();
  late Future<List<Product>> _productsFuture;
  @override
  void initState() {
    super.initState();
    _productsFuture = _productService.fetchProducts();
  }
  Future<void> _refreshProducts() async {
    setState(() { _productsFuture = _productService.fetchProducts(); });
  }

  void _showStockErrorSnackBar(String productName) {
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock máximo alcanzado para $productName'),
          backgroundColor: Colors.orange,
        ),
      );
  }
   void _showNoStockSnackBar(String productName) {
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$productName está agotado'),
          backgroundColor: Colors.red,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshProducts,
      child: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay productos.'));
          } else {
            final products = snapshot.data!;
            return ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ListTile(
                    leading: CircleAvatar( /* ... icono stock ... */ backgroundColor: Colors.deepPurple.shade100, child: Text(product.stock.toString(), style: TextStyle(color: Colors.deepPurple.shade900))),
                    title: Text(product.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column( /* ... descripción y empresa ... */ crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(product.descripcion), Text('Vendido por: ${product.nombreEmpresa}', style: const TextStyle(fontSize: 12, color: Colors.grey)), ]),
                    trailing: Row( // Usar Row para precio y botón +
                       mainAxisSize: MainAxisSize.min, // Para que no ocupe todo el ancho
                       children: [
                          Text('\$${product.precio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          const SizedBox(width: 8), // Espacio
                          // ¡NUEVO! Botón para añadir al carrito
                          IconButton(
                            icon: const Icon(Icons.add_shopping_cart, color: Colors.deepPurple),
                            tooltip: 'Añadir al carrito',
                            onPressed: product.stock > 0 ? () { // Solo habilitar si hay stock
                              // Llamamos a la función estática de HomeScreen
                              HomeScreen.addToCart(product);
                              // Mostrar feedback si no se pudo añadir
                               if (HomeScreen._cart.containsKey(product.id) && HomeScreen._cart[product.id]!.quantity == product.stock && product.stock > 0) {
                                _showStockErrorSnackBar(product.nombre);
                              } else if (product.stock <= 0 && !HomeScreen._cart.containsKey(product.id)) {
                                _showNoStockSnackBar(product.nombre);
                              }
                            } : null, // Deshabilitar si stock es 0
                          ),
                       ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

// --- Widget del Panel de ADMIN (Sin cambios) ---
class AdminPanel extends StatefulWidget { /* ... código sin cambios ... */
 const AdminPanel({super.key}); @override State<AdminPanel> createState() => _AdminPanelState();
}
class _AdminPanelState extends State<AdminPanel> {
  final AdminService _adminService = AdminService(); late Future<List<EmpresaDto>> _empresasFuture;
  @override void initState() { super.initState(); _empresasFuture = _adminService.getEmpresas(); }
  Future<void> _refreshEmpresas() async { setState(() { _empresasFuture = _adminService.getEmpresas(); }); }
  void _showCrearEmpresaDialog(BuildContext context) { final emailController = TextEditingController(); final passwordController = TextEditingController(); final nombreController = TextEditingController(); final formKey = GlobalKey<FormState>(); showDialog( context: context, builder: (BuildContext dialogContext) { return AlertDialog( title: const Text('Crear Nueva Empresa'), content: Form( key: formKey, child: Column( mainAxisSize: MainAxisSize.min, children: <Widget>[ TextFormField(controller: emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, validator: (value) => (value == null || !value.contains('@')) ? 'Email inválido' : null,), TextFormField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true, validator: (value) => (value == null || value.length < 6) ? 'Mínimo 6 caracteres' : null,), TextFormField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre Completo'), validator: (value) => (value == null || value.isEmpty) ? 'Nombre requerido' : null,), ], ), ), actions: <Widget>[ TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(dialogContext).pop(),), ElevatedButton(child: const Text('Crear'), onPressed: () async { if (formKey.currentState!.validate()) { bool success = await _adminService.crearEmpresa( emailController.text, passwordController.text, nombreController.text, ); Navigator.of(dialogContext).pop(); if (success) { _refreshEmpresas(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empresa creada'))); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al crear empresa'))); } } },), ], ); }, ); }
  @override Widget build(BuildContext context) { return Column( children: [ Padding( padding: const EdgeInsets.all(8.0), child: ElevatedButton.icon( icon: const Icon(Icons.add_business), label: const Text('Crear Nueva Empresa'), onPressed: () => _showCrearEmpresaDialog(context), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)), ), ), const Divider(), const Padding( padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Empresas Registradas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), ), Expanded( child: RefreshIndicator( onRefresh: _refreshEmpresas, child: FutureBuilder<List<EmpresaDto>>( future: _empresasFuture, builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); } else if (snapshot.hasError) { return Center(child: Text('Error: ${snapshot.error}')); } else if (!snapshot.hasData || snapshot.data!.isEmpty) { return const Center(child: Text('No hay empresas registradas.')); } else { final empresas = snapshot.data!; return ListView.builder( itemCount: empresas.length, itemBuilder: (context, index) { final empresa = empresas[index]; return ListTile( leading: const Icon(Icons.business), title: Text(empresa.nombreCompleto), subtitle: Text(empresa.email), trailing: Text('${empresa.cantidadProductos} prod.'), ); }, ); } }, ), ), ), ], ); }
}

// --- Widget del Panel de EMPRESA (Sin cambios) ---
class EmpresaPanel extends StatefulWidget { /* ... código sin cambios ... */
 const EmpresaPanel({super.key}); @override State<EmpresaPanel> createState() => _EmpresaPanelState();
}
class _EmpresaPanelState extends State<EmpresaPanel> {
  final EmpresaService _empresaService = EmpresaService(); late Future<List<Product>> _misProductosFuture;
  @override void initState() { super.initState(); _misProductosFuture = _empresaService.getMisProductos(); }
  Future<void> _refreshMisProductos() async { setState(() { _misProductosFuture = _empresaService.getMisProductos(); }); }
  void _showCrearProductoDialog(BuildContext context) { final nombreController = TextEditingController(); final descController = TextEditingController(); final precioController = TextEditingController(); final stockController = TextEditingController(); final formKey = GlobalKey<FormState>(); showDialog( context: context, builder: (BuildContext dialogContext) { return AlertDialog( title: const Text('Crear Nuevo Producto'), content: Form( key: formKey, child: Column( mainAxisSize: MainAxisSize.min, children: <Widget>[ TextFormField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre Producto'), validator: (value) => (value == null || value.isEmpty) ? 'Nombre requerido' : null,), TextFormField(controller: descController, decoration: const InputDecoration(labelText: 'Descripción'),), TextFormField(controller: precioController, decoration: const InputDecoration(labelText: 'Precio (ej. 75.50)'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (value) { if (value == null || value.isEmpty) return 'Precio requerido'; if (double.tryParse(value) == null) return 'Número inválido'; if (double.parse(value) <= 0) return 'Precio debe ser positivo'; return null; },), TextFormField(controller: stockController, decoration: const InputDecoration(labelText: 'Stock (ej. 120)'), keyboardType: TextInputType.number, validator: (value) { if (value == null || value.isEmpty) return 'Stock requerido'; if (int.tryParse(value) == null) return 'Número inválido'; if (int.parse(value) < 0) return 'Stock no puede ser negativo'; return null; },), ], ), ), actions: <Widget>[ TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(dialogContext).pop(),), ElevatedButton(child: const Text('Crear'), onPressed: () async { if (formKey.currentState!.validate()) { final double? precio = double.tryParse(precioController.text); final int? stock = int.tryParse(stockController.text); if (precio != null && stock != null) { bool success = await _empresaService.crearProducto( nombreController.text, descController.text, precio, stock, ); Navigator.of(dialogContext).pop(); if (success) { _refreshMisProductos(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto creado'))); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al crear producto'))); } } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Precio o Stock inválidos'))); } } },), ], ); }, ); }
  @override Widget build(BuildContext context) { return Column( children: [ Padding( padding: const EdgeInsets.all(8.0), child: ElevatedButton.icon( icon: const Icon(Icons.add_shopping_cart), label: const Text('Crear Nuevo Producto'), onPressed: () => _showCrearProductoDialog(context), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)), ), ), const Divider(), const Padding( padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Mis Productos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), ), Expanded( child: RefreshIndicator( onRefresh: _refreshMisProductos, child: FutureBuilder<List<Product>>( future: _misProductosFuture, builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); } else if (snapshot.hasError) { return Center(child: Text('Error: ${snapshot.error}')); } else if (!snapshot.hasData || snapshot.data!.isEmpty) { return const Center(child: Text('Aún no tienes productos creados.')); } else { final misProductos = snapshot.data!; return ListView.builder( itemCount: misProductos.length, itemBuilder: (context, index) { final product = misProductos[index]; return Card( margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), child: ListTile( leading: CircleAvatar(child: Text(product.stock.toString())), title: Text(product.nombre, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(product.descripcion), trailing: Text('\$${product.precio.toStringAsFixed(2)}'), ), ); }, ); } }, ), ), ), ], ); }
}

// --- ¡NUEVO! Pantalla del Carrito ---
class CartScreen extends StatefulWidget {
  final Map<int, CartItem> cart; // Recibe el carrito desde HomeScreen

  const CartScreen({super.key, required this.cart});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final OrderService _orderService = OrderService();
  bool _isLoading = false; // Para el botón de "Realizar Pedido"

  // Calcula el total del carrito
  double get _cartTotal {
    double total = 0.0;
    widget.cart.forEach((key, item) {
      total += item.subtotal;
    });
    return total;
  }

  // Función para realizar el pedido
  Future<void> _placeOrder() async {
    if (widget.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El carrito está vacío')));
      return;
    }

    setState(() { _isLoading = true; });

    // 1. Crear la lista de items para la API
    List<OrderItemCreateRequest> orderItems = [];
    widget.cart.forEach((productId, cartItem) {
      orderItems.add(OrderItemCreateRequest(
        productoId: productId,
        cantidad: cartItem.quantity,
      ));
    });

    // 2. Crear el objeto de la orden
    final orderRequest = OrderCreateRequest(items: orderItems);

    // 3. Llamar al servicio
    try {
      bool success = await _orderService.crearOrden(orderRequest);
       if (!mounted) return; // Chequeo por si la pantalla se cierra

      if (success) {
        // Éxito: Mostrar mensaje y volver a HomeScreen indicando éxito
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido realizado con éxito!'), backgroundColor: Colors.green,));
        // Devolvemos 'true' para que HomeScreen limpie el carrito
        Navigator.pop(context, true);
      }
      // Si falla, el servicio ya lanzó una excepción que manejamos abajo
    } catch (e) {
       // Error (ej. stock insuficiente desde la API, o conexión)
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al realizar pedido: ${e.toString()}'), backgroundColor: Colors.red,));
    } finally {
      // Siempre quitar el indicador de carga
      if (mounted) {
         setState(() { _isLoading = false; });
      }
    }
  }

  // --- Funciones para modificar cantidad en el carrito ---
  void _increaseQuantity(int productId) {
    setState(() {
      if (widget.cart.containsKey(productId)) {
        // Verificar stock antes de aumentar
        if (widget.cart[productId]!.quantity < widget.cart[productId]!.product.stock) {
           widget.cart[productId]!.quantity++;
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Stock máximo para ${widget.cart[productId]!.product.nombre}'))
            );
        }
      }
    });
     // Actualizar badge en HomeScreen (aunque no estemos viéndolo)
     HomeScreen.cartItemCount.value = widget.cart.length;
  }

  void _decreaseQuantity(int productId) {
    setState(() {
      if (widget.cart.containsKey(productId)) {
        if (widget.cart[productId]!.quantity > 1) {
          widget.cart[productId]!.quantity--;
        } else {
          // Si la cantidad es 1, eliminar el item
          widget.cart.remove(productId);
        }
      }
    });
     HomeScreen.cartItemCount.value = widget.cart.length; // Actualizar badge
  }

   void _removeItem(int productId) {
     setState(() {
       widget.cart.remove(productId);
     });
     HomeScreen.cartItemCount.value = widget.cart.length; // Actualizar badge
   }


  @override
  Widget build(BuildContext context) {
    // Convertir el Map a una Lista para el ListView
    final cartItemsList = widget.cart.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Carrito'),
      ),
      body: Column(
        children: [
          // Lista de Items en el carrito
          Expanded(
            child: cartItemsList.isEmpty
                ? const Center(child: Text('Tu carrito está vacío.'))
                : ListView.builder(
                    itemCount: cartItemsList.length,
                    itemBuilder: (context, index) {
                      final item = cartItemsList[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(item.product.nombre),
                        subtitle: Text('Precio: \$${item.product.precio.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                              onPressed: () => _decreaseQuantity(item.product.id),
                              tooltip: 'Quitar uno',
                            ),
                            Text(item.quantity.toString(), style: const TextStyle(fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              onPressed: () => _increaseQuantity(item.product.id),
                               tooltip: 'Añadir uno',
                            ),
                             IconButton(
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              onPressed: () => _removeItem(item.product.id),
                               tooltip: 'Eliminar del carrito',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Resumen y Botón de Pedido
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('\$${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _placeOrder,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
    backgroundColor: Colors.deepPurple,
             foregroundColor: Colors.white,
                           textStyle: const TextStyle(fontSize: 18)
                        ),
                        child: const Text('Realizar Pedido'),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


