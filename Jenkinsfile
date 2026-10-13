
pipeline {
    agent any

    triggers {
        pollSCM('H/2 * * * *')
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup Python Environment') {
            steps {
                bat '''
                    python --version
                    python -m venv .venv
                    .venv\\Scripts\\python.exe -m pip install --upgrade pip
                    .venv\\Scripts\\python.exe -m pip install -r requirements.txt
                '''
            }
        }

        stage('Syntax Check') {
            steps {
                bat '''
                    .venv\\Scripts\\python.exe -m compileall -q app.py
                '''
            }
        }

        stage('Run Pytest') {
            steps {
                bat '''
                    .venv\\Scripts\\python.exe -m pytest -v
                '''
            }
        }
    }

    post {
        success {
            echo 'ACEest Fitness build and tests passed.'
        }

        failure {
            echo 'ACEest Fitness pipeline failed. Review the stage logs.'
        }

        always {
            echo 'Jenkins pipeline execution completed.'
        }
    }
}
