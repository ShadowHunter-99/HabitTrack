import 'package:flutter/material.dart';

/// Datos que devuelve el diálogo una vez validados: nombre y descripción.
typedef HabitInput = ({String name, String description});

/// Diálogo para crear un hábito nuevo o editar uno existente.
///
/// Cuando se pasan [initialName] / [initialDescription] el diálogo entra
/// en modo edición: precarga los campos y ajusta títulos y botones.
///
/// No accede a la base de datos ni al provider: solo valida la entrada y
/// devuelve un [HabitInput] mediante `Navigator.pop`. La pantalla que lo
/// invocó decide qué hacer con el resultado. Esto mantiene el diálogo
/// independiente y fácil de probar.
class AddHabitDialog extends StatefulWidget {
  const AddHabitDialog({
    super.key,
    this.initialName,
    this.initialDescription,
  });

  /// Nombre actual del hábito (solo en modo edición).
  final String? initialName;

  /// Descripción actual del hábito (solo en modo edición).
  final String? initialDescription;

  @override
  State<AddHabitDialog> createState() => _AddHabitDialogState();
}

class _AddHabitDialogState extends State<AddHabitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  /// `true` cuando el diálogo se abrió para editar un hábito existente.
  bool get _isEditing =>
      widget.initialName != null || widget.initialDescription != null;

  @override
  void initState() {
    super.initState();
    // Los controladores se crean aquí (y no como campos finales) porque
    // necesitan el `widget`, que aún no existe en la declaración.
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    // Es fundamental liberar los controladores para evitar fugas de memoria.
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Valida el formulario y, si todo es correcto, cierra el diálogo
  /// devolviendo los datos introducidos.
  void _submit() {
    // `currentState!` es seguro aquí porque el formKey está asignado al
    // Form del build y _submit solo se llama desde sus botones.
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(
        (
          name: _nameController.text,
          description: _descriptionController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar hábito' : 'Nuevo hábito'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: !_isEditing, // al editar no tape el nombre con el teclado
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej.: Leer 20 minutos',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre no puede estar vacío';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Ej.: Leer antes de dormir, sin móvil',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // cancelar → null
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Guardar cambios' : 'Guardar'),
        ),
      ],
    );
  }
}
