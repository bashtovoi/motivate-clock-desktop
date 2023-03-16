package org.motivateclock.model
{

    import flash.events.Event;
    import flash.events.EventDispatcher;

    import org.motivateclock.Model;
    import org.motivateclock.enum.ProcessTypeEnum;
    import org.motivateclock.enum.TextKeyEnum;
    import org.motivateclock.enum.TypeEnum;
    import org.motivateclock.events.McEvent;
    import org.motivateclock.events.ModelEvent;
    import org.motivateclock.interfaces.IProcess;
    import org.motivateclock.model.statistic.DataBase;

    /**
     * @author: Valeriy Bashtovoy
     *
     */
    public class ProjectsModel extends EventDispatcher
    {
        private static var instance:ProjectsModel;
        private static var isSingleton:Boolean = false;

        public static const PROJECT_REMOVED:String = "project_removed";
        public static const PROJECT_NAME_CHANGE:String = "project_name_change";
        public static const MANUAL_MODE:String = "0";

        private var _currentProject:Project;
        private var _projectsList:Vector.<Project> = new <Project>[];

        private var _model:Model;

        private var _numSaved:int = 0;
        private var _numSaving:int = 0;

        public static function getInstance():ProjectsModel
        {
            if (!instance)
            {
                isSingleton = true;
                instance = new ProjectsModel();
                isSingleton = false;
            }

            return instance;
        }

        public function ProjectsModel()
        {
            if (!isSingleton)
            {
                throw new Error(this + "this is singletone, use getInstance()");
            }
        }

        public function set model(value:Model):void
        {
            _model = value;
        }

        private function init():void
        {
            var length:int = _projectsList.length;
            var project:Project;
            var currentProjectId:String = ProjectsModel.MANUAL_MODE;

            for (var i:int = 0; i < length; i++)
            {
                project = _projectsList[i];

                if (project.id == ProjectsModel.MANUAL_MODE)
                {
                    _projectsList.splice(i, 1);
                    _projectsList.unshift(project);
                }

                if (!project.isCurrent)
                {
                    continue;
                }

                currentProjectId = project.id;
            }

            if (_projectsList.length > 0)
            {
                selectProject(currentProjectId);
            }
            else
            {
                // both projects should be created only on the first app launch;
                createManualModeProject();
                createFirstProject();
            }
        }

        public function get projectsList():Vector.<Project>
        {
            return _projectsList;
        }

        public function get currentProject():Project
        {
            return _currentProject;
        }

        public function getProjectById(id:String):Project
        {
            var project:Project;

            for each (var p:Project in _projectsList)
            {
                if (p.id == id)
                {
                    project = p;
                    break;
                }
            }

            return project;
        }

        public function selectProject(id:String):void
        {
            if (_currentProject && _currentProject.id == id)
            {
                return;
            }

            var length:int = _projectsList.length;
            var project:Project;

            for (var i:int = 0; i < length; i++)
            {
                project = _projectsList[i];

                project.isCurrent = (project.id == id);

                if (!project.isCurrent)
                {
                    continue;
                }

                _projectsList.splice(i, 1);

                if (length == 1 || project.id == ProjectsModel.MANUAL_MODE)
                {
                    _projectsList.splice(0, 0, project);
                }
                else
                {
                    _projectsList.splice(1, 0, project);
                }

                _currentProject = project;
            }

            trace(this, "currentProject:", _currentProject);

            dispatchEvent(new ModelEvent(ModelEvent.PROJECT_CHANGE))
        }

        public function resetProject(project:Project):void
        {
            if (!project)
            {
                trace(this, "resetProject: Warning. Project is not defined.");
                return;
            }

            _model.currentType = TypeEnum.IDLE;

            project.reset();

            _model.dataBase.resetProjectStatistic(project.id);
        }

        public function updateProjectName(project:Project, name:String):void
        {
            if (project)
            {
                project.name = name;
                dispatchEvent(new Event(ProjectsModel.PROJECT_NAME_CHANGE));
            }
        }

        public function removeProject(project:Project):void
        {
            DataBase.getInstance().resetProjectStatistic(project.id);
            DataBase.getInstance().removeProject(project.id);

            try
            {
                _projectsList.splice(_projectsList.indexOf(project), 1);
            }
            catch (error:Error)
            {
            }

            if (project.id == _currentProject.id)
            {
                selectProject(ProjectsModel.MANUAL_MODE);
            }

            dispatchEvent(new Event(ProjectsModel.PROJECT_REMOVED));
        }

        public function createProject(name:String, applications:String = "", id:String = ""):void
        {
            // tricky way to launch project in auto mode;
            const process:IProcess = new Process(ProcessTypeEnum.SITE, 'motivateclock.org', 'motivateclock.org');

            var project:Project = new Project();
            project.name = name;
            project.creationDate = new Date();
            project.applications = (applications != "") ? applications : process.serialize();

            project.id = (id != "") ? id : new Date().getTime().toString();

            _projectsList.push(project);

            selectProject(project.id);

            DataBase.getInstance().addProject(project);
        }

        public function load():void
        {
            DataBase.getInstance().addEventListener(McEvent.DB_LOADED, bdLoadHandler);
            DataBase.getInstance().addEventListener(McEvent.PROJECTS_OBTAINED, projectsHandler);
            DataBase.getInstance().initialize();

            function bdLoadHandler(event:McEvent):void
            {
                DataBase.getInstance().getProjects();
            }

            function projectsHandler(event:McEvent):void
            {
                _projectsList = Vector.<Project>(event.result.reverse());

                trace(this, _projectsList);

                init();

                dispatchEvent(new McEvent(McEvent.LOAD_COMPLETE));
            }
        }

        // TODO should be moved to command;
        public function save():void
        {
            _model.dataBase.addEventListener(DataBase.PROJECT_UPDATED, updateHandler);

            _numSaving = 0;
            _numSaved = 0;

            for each (var project:Project in _projectsList)
            {
                if (!project.isChanged)
                {
                    continue;
                }

                _numSaving++;

                _model.dataBase.updateProject(project);

                project.isChanged = false;
            }

            if (_numSaving == 0)
            {
                dispatchSaveCompleteEvent();
            }
        }

        private function createManualModeProject():void
        {
            createProject(_model.languageModel.getText(TextKeyEnum.PROJECT_MANUAL_MODE), "", ProjectsModel.MANUAL_MODE);
        }

        private function createFirstProject():void
        {
            createProject(_model.languageModel.getText(TextKeyEnum.PROJECT_FIRST));
        }

        private function updateHandler(event:Event):void
        {
            _numSaved++;

            if (_numSaved == _numSaving)
            {
                dispatchSaveCompleteEvent();
            }
        }

        private function dispatchSaveCompleteEvent():void
        {
            _model.dataBase.removeEventListener(DataBase.PROJECT_UPDATED, updateHandler);
            dispatchEvent(new ModelEvent(ModelEvent.PROJECT_SAVE_COMPLETE));
        }
    }
}
