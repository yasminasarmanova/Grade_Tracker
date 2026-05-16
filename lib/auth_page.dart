
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLogin = false; // false = регистрация, true = вход
  bool isLoading = false;
  String? message;

  Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    isLoading = true;
    message = null;
  });

  try {
    if (isLogin) {
      // вход
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (res.session != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() => message = 'Ошибка входа. Проверьте данные.');
      }
    } else {
      // регистрация
      final res = await Supabase.instance.client.auth.signUp(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
      data: {'name': nameController.text.trim()},
    );

    if (res.user != null) {
      // добавляем пользователя в таблицу public.users
      await Supabase.instance.client.from('users').insert({
        'id': res.user!.id, // id из auth.users
        'name': nameController.text.trim(),
      });

      if (mounted) {
        setState(() {
          isLogin = true;
          message = '✅ Аккаунт создан! Теперь войдите.';
        });
      }
    } else {
      setState(() => message = 'Ошибка регистрации.');
    }

    }
  } catch (e) {
    // 💡 более дружелюбная ошибка
    if (e.toString().contains('duplicate key value')) {
      setState(() => message = '⚠️ Этот email уже зарегистрирован.');
    } else {
      setState(() => message = '⚠️ Ошибка: ${e.toString()}');
    }
  } finally {
    setState(() => isLoading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFD),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              
              children: [
                const Icon(Icons.school, size: 80, color: Color(0xFF661E35)),
                const SizedBox(height: 10),
                Text(
                  isLogin ? 'Добро пожаловать!' : 'Создай свой аккаунт',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF661E35),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isLogin
                      ? 'Войди, чтобы увидеть свои предметы и оценки'
                      : 'Следи за своими успехами и оценивай прогресс',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
                if (!isLogin)
                  Column(
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Имя',
                          prefixIcon: const Icon(Icons.person_outline),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                            color: Color.fromRGBO(201, 201, 201, 1), // цвет рамки, когда поле НЕ в фокусе
                            width: 1.5,
                          ),
                          ),focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 153, 49, 82), // цвет рамки, когда поле в фокусе
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (val) =>
                            val != null && val.isNotEmpty ? null : 'Введите имя',
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                TextFormField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                      color: Color.fromRGBO(201, 201, 201, 1), // цвет рамки, когда поле НЕ в фокусе
                      width: 1.5,
                    ),
                    ),focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 153, 49, 82), // цвет рамки, когда поле в фокусе
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (val) => val != null && val.contains('@')
                      ? null
                      : 'Введите корректный email',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: const Icon(Icons.lock_outline),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                      color: Color.fromRGBO(201, 201, 201, 1), // цвет рамки, когда поле НЕ в фокусе
                      width: 1.5,
                    ),
                    ),focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 153, 49, 82), // цвет рамки, когда поле в фокусе
                        width: 2,
                      ),
                    ),
                  ),
                  obscureText: true,
                  validator: (val) =>
                      val != null && val.length >= 6 ? null : 'Минимум 6 символов',
                ),
                const SizedBox(height: 24),
                isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF762640))
                    : ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF661E35),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 70, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          isLogin ? 'Войти' : 'Зарегистрироваться',
                          style: const TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                const SizedBox(height: 16),
                if (message != null)
                  Text(
                    message!,
                    style: TextStyle(
                      color: message!.contains('✅')
                          ? Colors.green
                          : Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isLogin = !isLogin;
                      message = null;
                    });
                  },
                  child: Text(
                    isLogin
                        ? 'У вас нет аккаунта? Зарегистрируйтесь'
                        : 'Уже есть аккаунт? Войдите',
                    style: const TextStyle(
                      color: Color(0xFF661E35),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}