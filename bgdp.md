npm publish --access public --otp=YOUR_2FA_CODE

gem push grim-reaper-1.0.5.gem --otp YOUR_OTP_CODE

5
@/java_grim 0051298b-de08-4dbd-8866-29d82ca6e97f is the id for maven, so.grim is the name space



./deploy.sh --skip-npm --skip-nuget -m "Python 1.0.7, Ruby 1.0.2, Rust with proper license"

Successfully deployed:
  - Python 1.0.7
  - Ruby 1.0.2
  - JavaScript (previously)
  - C# (previously)

  ✅ Fixed and ready to deploy:
  - Rust 1.0.1 (fixed category from
  "system-administration" to "compression")

  ✅ Added all skip options:
  - --skip-npm / --skip-python / --skip-pypi
  - --skip-ruby / --skip-gem
  - --skip-rust / --skip-crates
  - --skip-php / --skip-go
  - --skip-java / --skip-maven
  - --skip-nuget

  Now you can deploy just Rust with:
  ./deploy.sh --skip-npm --skip-rust --skip-nuget --skip-python --skip-ruby  --skip-java -m "minor fixes"

  Or use the help to see all options:
  ./deploy.sh --help


  