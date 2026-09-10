import 'package:glass_forge_workbench/exports.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              SvgPicture.asset(
                AssetPaths.emblemDark,
                height: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome',
                style: context.h1,
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to continue',
                style: context.p1Medium.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              CustomSocialAuthButton(
                text: 'Sign in with Google',
                iconPath: AssetPaths.googleIcon,
                onPressed: () {
                  // TODO(codeable): Implement Google sign-in
                },
              ),
              const SizedBox(height: 16),
              CustomSocialAuthButton(
                text: 'Sign in with Apple',
                iconPath: AssetPaths.appleIcon,
                onPressed: () {
                  // TODO(codeable): Implement Apple sign-in
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
