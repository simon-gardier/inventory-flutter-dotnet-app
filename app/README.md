```
    __  ___     _    __           __                      ___              
   /  |/  /_  _| |  / /__  ____  / /_____  _______  __   /   |  ____  ____ 
  / /|_/ / / / / | / / _ \/ __ \/ __/ __ \/ ___/ / / /  / /| | / __ \/ __ \
 / /  / / /_/ /| |/ /  __/ / / / /_/ /_/ / /  / /_/ /  / ___ |/ /_/ / /_/ /
/_/  /_/\__, / |___/\___/_/ /_/\__/\____/_/   \__, /  /_/  |_/ .___/ .___/ 
       /____/                                /____/         /_/   /_/      
```
# MyVentory's app repository
Repository for the project application!

## 🧪Documentation
### Tech stack
- [Flutter](https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Technologies/Technology%20Choices%20for%20MyInventory%20System/).

### Project structure
- `Dockerfile.apk` and `Dockerfile.web` are used to create the nginx servers container that serves the download of the application and the website on openshift.
- `MyVentoryApp` contains the Flutter project.
- `MyVentoryApp/lib/` contains the main code of the application.
- `Openshift` contains the YAML fils for the deployment of the app on openshift.
- `gitlab-ci.yml` builds the apk, create an nginx (http server) image with the apk and push it to the container registry.

### Development environment
- Install the preferred IDE: [Visual Studio Code](https://code.visualstudio.com/)
    - Open the project in VSCode, notifications will appear to install the required extensions. **Accept everything**
- Install Flutter: [installation guide](https://flutter.dev/docs/get-started/install)
- [Android Studio](https://developer.android.com/studio) is required to run the application on an emulator.
    - [Set up an Android emulator](https://developer.android.com/studio/run/emulator) 
- Build application locally: `flutter build apk --release`
    - Note: The apk will be placed in `build/app/outputs/flutter-apk/app-release.apk`.
- Run the application locally: 
    - Clone the [my-ventory-backend](https://gitlab.uliege.be/SPEAM/2024-2025/team5/myventorybackend) repository and follow the instructions to run the backend locally.
    - Start the application: `flutter run --dart-define=API_BASE_URL=http://backend_url`. **Note**: A device (VM/Smartphone) must be connected to VSCode to run the application.
        - Add the flag ``-d chrome` to run the application in Chrome.
        - By default the applications connects **to the backend running on openshift**. To connect to a local backend, you need to set the `API_BASE_URL` environment variable to the local backend URL.
            - `http://10.0.2.2/api` connects to the backend on your machine when running the application in an emulator.
            - `http://localhost/api` connects to the backend on your machine when running the website on Chrome.
            - `http://local_ip` connects to the backend on your machine when running the application on your smartphone. See `ipconfig` to know your local ip address. More details [here](https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Technologies/Local%20development%20and%20testing/).
    - To connect a device (VM or smartphone):
        - Start the device in Android studio / Connect the smartphone to the computer.
        - Select the device in the bottom right corner of VSCode.
        - Start the application. It should appear on the device.
- Run the integration tests:
    - Just as for `Run the application locally`, you must start the backend locally and set the `API_BASE_URL` environment variable to the local backend URL.
    - The integration tests are made to be run on an androind emulator. Thus, you must have one running.
    - Start the tests with : `flutter test integration_test/run_integration_tests.dart  --dart-define=API_BASE_URL=http://10.0.2.2/api`

### CI/CD
- See the [Deployement](https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Infra/) wiki page to understand how the pipeline works.

## 🔗Usefull references
- [Wiki](https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Main/)
- [Technologies used](https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Technologies/)
- [Infra doc](https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Infra/)
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [online documentation](https://docs.flutter.dev/), which offers tutorials, samples, guidance on mobile development, and a full API reference.

## ✍️Main contributors
- Developpement: [Alexandre](alexandre.luzzi@student.uliege.be), [Julien MP](julien.mparirwa@student.uliege.be), [Marzouk](marzouk.ouro-gomma@student.uliege.be)
- DevOps: [Simon](s.gardier@student.uliege.be)
