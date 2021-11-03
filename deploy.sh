node('master') {
    try {
        notifyBuild('STARTED')
      //  notify = "${notify}"
        tag = "${tag}"
        print "Parameters :$params"
          stage('SCM Checkout'){
            checkout([$class: 'GitSCM', branches: [[name: '*/$Branch']], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '99eda386-8d95-4cdb-91be-48ebb5d3d16f', url: 'https://bitbucket.org/nexuireact/nex-lokalise.git']]])
            sh 'sed -i "s/%BUILD_NUMBER%/$(date +"%y%m%d.%H%M")/g" .env-acpt.json'
        }
   
    stage('Build'){
        
         if(tag==''){
             def now = new Date()
              tag = now.format("yyMMdd.HHmm", TimeZone.getTimeZone('UTC'))
            print 'Build Tag : '+tag  
         }
//        sh 'yarn install --silent'
//		  sh 'yarn download:staging'
          
          sh "tar --exclude='node_modules' -cf nex-lokalise.tgz * .env-acpt.json"
         withEnv(['CLOUDSDK_PYTHON=/usr/bin/python']) {
             sh 'CI=false  docker build -f Dockerfile.acpt -t gcr.io/nextory-test-platform/nex-lokalise:'+tag+' .'
         }
   }

       stage('Deploy'){
           
            withEnv(['CLOUDSDK_PYTHON=/usr/bin/python']) {
                sh 'gcloud container clusters get-credentials --region asia-east1-a  vpc-istio-custom-6'
                sh 'gcloud docker -- push gcr.io/nextory-test-platform/nex-lokalise:'+tag
                sh 'kubectl set image deployment/nex-lokalise nex-lokalise=gcr.io/nextory-test-platform/nex-lokalise:'+tag+' -n web'
        }  
   }
      
} catch (e) {
    // If there was an exception thrown, the build failed
    currentBuild.result = "FAILED"
    throw e
  } finally {
    // Success or failure, always send notifications
    notifyBuild(currentBuild.result)
  }
}

def notifyBuild(String buildStatus = 'STARTED') {
  // build status of null means successful
  buildStatus =  buildStatus ?: 'SUCCESSFUL'

  // Default values
  def colorName = 'RED'
  def colorCode = '#FF0000'
  def subject = "${buildStatus}: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'"
  def summary = "${subject} (${env.BUILD_URL}console)"
  
  // Override default values based on build status
  if (buildStatus == 'STARTED') {
    color = 'YELLOW'
    colorCode = '#FFFF00'
  } else if (buildStatus == 'SUCCESSFUL') {
    color = 'GREEN'
    colorCode = '#00FF00'
  } else {
    color = 'RED'
    colorCode = '#FF0000'
  }

  // Send notifications
  slackSend (color: colorCode, message: summary)

}
