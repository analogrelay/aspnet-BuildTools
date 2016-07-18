using System;
using System.IO;
using System.Reflection;
using System.Runtime.Loader;

namespace Microsoft.AspNetCore.Build.Launcher
{
    public class Program
    {
        public static int Main(string[] args)
        {
            // Try to load MSBuild.
            var msbuildPath = Path.Combine(AppContext.BaseDirectory, "runtimes", "any", "native", "MSBuild.exe");
            if(!File.Exists(msbuildPath))
            {
                return Error($"Could not find MSBuild.exe at '{msbuildPath}'. Ensure you are running from the published output.");
            }

            var msbuildAssembly = AssemblyLoadContext.Default.LoadFromAssemblyPath(msbuildPath);
            if(msbuildAssembly == null)
            {
                return Error("Failed to load MSBuild.exe");
            }

            var msbuildApp = msbuildAssembly.GetType("Microsoft.Build.CommandLine.MSBuildApp");
            if(msbuildApp == null)
            {
                return Error("Failed to load MSBuildApp type from MSBuild.exe");
            }

            var method = msbuildApp.GetRuntimeMethod("Main", new[] { typeof(string[]) });
            if(method == null)
            {
                return Error("Failed to load Main method from MSBuildApp");
            }

            return (int)method.Invoke(null, new[] { args });
        }

        private static int Error(string message)
        {
            Console.Error.WriteLine(message);
            return 1;
        }
    }
}
