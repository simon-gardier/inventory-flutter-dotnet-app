```
    __  ___     _    __           __                      ____             __                  __
   /  |/  /_  _| |  / /__  ____  / /_____  _______  __   / __ )____ ______/ /_____  ____  ____/ /
  / /|_/ / / / / | / / _ \/ __ \/ __/ __ \/ ___/ / / /  / __  / __ `/ ___/ //_/ _ \/ __ \/ __  / 
 / /  / / /_/ /| |/ /  __/ / / / /_/ /_/ / /  / /_/ /  / /_/ / /_/ / /__/ ,< /  __/ / / / /_/ /  
/_/  /_/\__, / |___/\___/_/ /_/\__/\____/_/   \__, /  /_____/\__,_/\___/_/|_|\___/_/ /_/\__,_/   
       /____/                                /____/                                              
```
# MyVentory's backend repository
Repository for the project backend!

## 🧪Quick Documentation
### Tech stack
- [Dotnet](https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Technologies/Technology%20Choices%20for%20MyInventory%20System/).
- [Postgresql](https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Technologies/Technology%20Choices%20for%20MyInventory%20System/).

### Project structure
- `myventoryapi.sln`: [Solution file](https://learn.microsoft.com/en-us/visualstudio/ide/solutions-and-projects-in-visual-studio?view=vs-2022#solutions) referencing the 2 [dotnet projects](https://learn.microsoft.com/en-us/visualstudio/ide/solutions-and-projects-in-visual-studio?view=vs-2022#projects).
- `MyVentoryApi/`: dotnet project for the backend itself.
- `MyVentoryApi.Tests/`: dotnet project for the unit testing of the backend.
- `Openshift`: The YAML files used to deploy the infrastructure on Openshift

### Development environment
- Install the [.NET 9.0](https://dotnet.microsoft.com/en-us/download/dotnet/9.0) sdk
- Install the recommended IDE: [Visual Studio Code](https://code.visualstudio.com/)
- Open the project in [Visual Studio Code](https://code.visualstudio.com/), notifications will appear to install the required extensions. **Accept everything**
- Setup your environment: 
    - Create a `database.env` file at the root of the project. See `database.env_template` for a template with explanations on where to find the necessary keys.
    - In `MyVentoryApi`, create a `.env` file in the folder `MyVentoryApi/`. See `MyVentoryApi/.env_template` for a template with explanations on where to find the necessary keys.
    - You need to trust the SSL certificate to use the backend locally, from `MyVentoryApi/` type: `dotnet dev-certs https --trust`
- Run the backend **locally**:
    - Start Docker desktop
    - **Start the DB**: `docker-compose --env-file database.env up -d` (remove the `-d` if you want the logs)
        - **Note:** You need a database.env file to use `run`. See the "Environment" section above.
        - Inspect the database by opening a terminal in the container (from the Docker GUI) and type: `psql -U Team5 -d MyVentory`
        - Inspect the database in pgAdmin [here](http://localhost:5050), email: `admin@myventory.com`, password: same as [POSTGRES_PASSWORD in "Variables" section](https://gitlab.uliege.be/SPEAM/2024-2025/team5/myventorybackend/-/settings/ci_cd).
            - After connection, right click `Servers` > `Register` > `Server`.
                - In General tab, Name: my-ventory-database
                - In Connection tab, Host name: my-ventory-database, Username: Team5, Password: same as [POSTGRES_PASSWORD in "Variables" section](https://gitlab.uliege.be/SPEAM/2024-2025/team5/myventorybackend/-/settings/ci_cd)
        - If you want to erase the DB, delete the volume from Docker Desktop.
        - Note: On pgAdmin hosted on openshift, the name and host name are **myventory-db-service**.
    - **Start the backend** (from the `MyVentoryApi` folder): `dotnet run`
        - Access the API doc page in local [here](https://localhost/).
- How to update the Database scheme:
    When you add a table / modify an exisiting table, you have to create a `Migration` to apply these changes to the DB.
    - Install EF CLI tools: `dotnet tool install --global dotnet-ef`
    - From the `MyVentoryApi` folder, run `dotnet ef migrations add <Name you want to give to the update of the DB (e.g. NewItemModel)>` to generate the migration files. They will be used automatically by the pod on Openshift.
- Run the tests in local (in the `MyVentoryApi.Tests` folder):
    You must first install [Docker](https://www.docker.com/) and follow the step from above ("**Start the DB**"), as the tests require the database engine to be running.
    - You can list the tests with: `dotnet test -t`
    - Run the tests with: `dotnet test --logger "html;LogFileName=test-results.html"`
    - Read the results of the tests: open the file `MyVentoryApi.Tests/TestResults/test-results.html` in your browser.
        - Note: the results are also available in the terminal from which you ran the tests (its just less readable).
    - Note: Running the tests delete and recreate your local database.
    - Note 2: You must copy your .env file from the `MyVentoryApi` folder to the `MyVentoryApi.Tests` folder.

### CI/CD
- Rules: the pipeline is triggered on every push to the **main** branch, except if the changes pushed are only in *.md files.
- Output:
    - Backend container image

## 🔗Usefull references
- [Wiki](https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Main/)
- [Data model](https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Formalized%20requirements/Entity%20Relationship%20Diagram/)
- [Infra doc](https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Infra/)
- [Technologies used](https://jira.montefiore.ulg.ac.be/xwiki/wiki/team0524/view/Technologies/)

## ✍️Main contributors
- CRUD API: [Simon](s.gardier@student.uliege.be), [Dario](dario.rinallo@student.uliege.be)
- External APIs: [Julien DR](julien.direnzo@student.uliege.be), [Marzouk](marzouk.ouro-gomma@student.uliege.be)
- DevOps: [Simon](s.gardier@student.uliege.be)
