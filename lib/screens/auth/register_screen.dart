import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/logger.dart';
import '../../providers/auth_provider.dart';
import '../../services/society_service.dart';
import '../../models/society_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/password_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final SocietyService _societyService = SocietyService();
  
  String _selectedRole = AppConstants.roleStudent;
  String? _selectedSocietyId;
  List<String> _selectedInterests = [];
  List<SocietyModel> _societies = [];
  bool _loadingSocieties = true;
  
  final List<String> _availableInterests = [
    'Technical',
    'Sports',
    'Literary',
    'Cultural',
    'Music',
    'Art',
    'Gaming',
    'Entrepreneurship',
  ];

  @override
  void initState() {
    super.initState();
    _loadSocieties();
  }

  Future<void> _loadSocieties() async {
    try {
      final societies = await _societyService.getAllSocieties();
      setState(() {
        _societies = societies;
        _loadingSocieties = false;
      });
    } catch (e) {
      AppLogger.error('Error loading societies', e);
      setState(() {
        _loadingSocieties = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate society selection for handlers
    if (_selectedRole == AppConstants.roleSocietyHandler && _selectedSocietyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a society'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    // Validate interests selection for students
    if (_selectedRole == AppConstants.roleStudent && _selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one interest'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
      role: _selectedRole,
      societyId: _selectedRole == AppConstants.roleSocietyHandler ? _selectedSocietyId : null,
      interests: _selectedRole == AppConstants.roleStudent ? _selectedInterests : null,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppConstants.homeRoute);
    } else if (mounted && authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Join us today!',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create an account to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.gray500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                CustomTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  prefixIcon: Icons.person_outline,
                  validator: Validators.name,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                
                PasswordTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Create a password',
                  validator: Validators.password,
                  textInputAction: TextInputAction.next,
                  showStrengthIndicator: true,
                ),
                const SizedBox(height: 16),
                
                PasswordTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Confirm your password',
                  validator: _validateConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                ),
                const SizedBox(height: 24),
                
                // Role Selection
                Text(
                  'I am a:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.gray300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Student'),
                        subtitle: const Text('Browse and register for events'),
                        value: AppConstants.roleStudent,
                        groupValue: _selectedRole,
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                            _selectedSocietyId = null;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: const Text('Society Handler'),
                        subtitle: const Text('Manage events for your society'),
                        value: AppConstants.roleSocietyHandler,
                        groupValue: _selectedRole,
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                            _selectedInterests = [];
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Society Selection (for handlers)
                if (_selectedRole == AppConstants.roleSocietyHandler) ...[
                  Text(
                    'Select Your Society:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _loadingSocieties
                      ? const Center(child: CircularProgressIndicator())
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.gray300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedSocietyId,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              border: InputBorder.none,
                              hintText: 'Choose a society',
                            ),
                            items: _societies.map((society) {
                              return DropdownMenuItem(
                                value: society.id,
                                child: Text('${society.shortName} - ${society.name}'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSocietyId = value;
                              });
                            },
                          ),
                        ),
                  const SizedBox(height: 24),
                ],
                
                // Interests Selection (for students)
                if (_selectedRole == AppConstants.roleStudent) ...[
                  Text(
                    'Select Your Interests:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableInterests.map((interest) {
                      final isSelected = _selectedInterests.contains(interest);
                      return FilterChip(
                        label: Text(interest),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedInterests.add(interest);
                            } else {
                              _selectedInterests.remove(interest);
                            }
                          });
                        },
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.primary,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                
                const SizedBox(height: 8),
                
                CustomButton(
                  text: 'Create Account',
                  onPressed: _register,
                  isLoading: authProvider.isLoading,
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
