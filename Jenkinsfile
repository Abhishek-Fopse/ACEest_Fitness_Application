
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
                sh '''
                    python3 --version
                    python3 -m venv .venv
                    .venv/bin/python -m pip install --upgrade pip
                    .venv/bin/python -m pip install -r requirements.txt
                '''
            }
        }

        stage('Syntax Check') {
            steps {
                sh '''
                    .venv/bin/python -m compileall -q app.py
                '''
            }
        }

        stage('Run Pytest') {
            steps {
                sh '''
                    .venv/bin/python -m pytest -v
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
